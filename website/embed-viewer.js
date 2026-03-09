// ABOUTME: Self-contained embed viewer for Divine video widget
// ABOUTME: Fetches Nostr profile + video events and renders an embeddable card

(function () {
    'use strict';

    // =========================================================================
    // Bech32 npub decoder (inline, no dependencies)
    // =========================================================================

    const BECH32_CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

    function bech32Decode(str) {
        str = str.toLowerCase();
        const sepIdx = str.lastIndexOf('1');
        if (sepIdx < 1) return null;

        const hrp = str.slice(0, sepIdx);
        const dataChars = str.slice(sepIdx + 1);
        const data = [];
        for (let i = 0; i < dataChars.length; i++) {
            const v = BECH32_CHARSET.indexOf(dataChars[i]);
            if (v === -1) return null;
            data.push(v);
        }

        // Strip 6-char checksum
        const payload = data.slice(0, -6);

        // Convert 5-bit groups to 8-bit bytes
        let acc = 0;
        let bits = 0;
        const bytes = [];
        for (const val of payload) {
            acc = (acc << 5) | val;
            bits += 5;
            while (bits >= 8) {
                bits -= 8;
                bytes.push((acc >> bits) & 0xff);
            }
        }
        return { hrp, bytes };
    }

    function npubToHex(npub) {
        if (!npub || !npub.startsWith('npub1')) return null;
        const decoded = bech32Decode(npub);
        if (!decoded || decoded.hrp !== 'npub' || decoded.bytes.length !== 32) return null;
        return decoded.bytes.map(b => b.toString(16).padStart(2, '0')).join('');
    }

    // =========================================================================
    // Constants
    // =========================================================================

    // TODO: Hardcoded relay list — if relays change, requires redeployment.
    // Consider fetching from a config endpoint in the future.
    const RELAYS = [
        'wss://relay.divine.video',
        'wss://relay.damus.io',
        'wss://nos.lol',
        'wss://relay.nostr.band',
        'wss://cache2.primal.net/v1'
    ];
    const RELAY_TIMEOUT = 8000;
    const KIND_METADATA = 0;
    const KIND_VIDEO = 34236;

    // =========================================================================
    // Relay connection helpers
    // =========================================================================

    function fetchFromRelay(relayUrl, filters, onEvent) {
        return new Promise(function (resolve) {
            var settled = false;
            function done() {
                if (settled) return;
                settled = true;
                resolve();
            }

            try {
                var ws = new WebSocket(relayUrl);
                var subId = 'emb_' + Math.random().toString(36).substring(2, 10);

                ws.onopen = function () {
                    ws.send(JSON.stringify(['REQ', subId].concat(filters)));
                };

                ws.onmessage = function (msg) {
                    try {
                        var parsed = JSON.parse(msg.data);
                        if (parsed[0] === 'EVENT' && parsed[2]) {
                            onEvent(parsed[2]);
                        } else if (parsed[0] === 'EOSE') {
                            ws.send(JSON.stringify(['CLOSE', subId]));
                            setTimeout(function () {
                                try { ws.close(); } catch (_) { /* ignore */ }
                            }, 100);
                            done();
                        }
                    } catch (_) { /* ignore parse errors */ }
                };

                ws.onerror = function () { done(); };
                ws.onclose = function () { done(); };

                setTimeout(function () {
                    try { if (ws.readyState === WebSocket.OPEN) ws.close(); } catch (_) { /* ignore */ }
                    done();
                }, RELAY_TIMEOUT);
            } catch (_) {
                done();
            }
        });
    }

    function fetchFromAllRelays(filters, onEvent) {
        var promises = RELAYS.map(function (url) {
            return fetchFromRelay(url, filters, onEvent);
        });
        return Promise.allSettled(promises);
    }

    // =========================================================================
    // Data fetching
    // =========================================================================

    function fetchProfile(pubkeyHex) {
        var profile = null;
        return fetchFromAllRelays(
            [{ kinds: [KIND_METADATA], authors: [pubkeyHex], limit: 1 }],
            function (evt) {
                if (evt.kind === KIND_METADATA) {
                    if (!profile || evt.created_at > profile.created_at) {
                        profile = evt;
                    }
                }
            }
        ).then(function () { return profile; });
    }

    function fetchVideos(pubkeyHex, count) {
        var videos = new Map(); // keyed by d-tag for dedup
        return fetchFromAllRelays(
            [{ kinds: [KIND_VIDEO], authors: [pubkeyHex], limit: count + 5 }],
            function (evt) {
                if (evt.kind === KIND_VIDEO) {
                    var dTag = getTagValue(evt.tags, 'd') || evt.id;
                    var existing = videos.get(dTag);
                    if (!existing || evt.created_at > existing.created_at) {
                        videos.set(dTag, evt);
                    }
                }
            }
        ).then(function () {
            // Sort newest first, limit to requested count
            return Array.from(videos.values())
                .sort(function (a, b) { return b.created_at - a.created_at; })
                .slice(0, count);
        });
    }

    // =========================================================================
    // Tag parsing helpers
    // =========================================================================

    function getTagValue(tags, name) {
        if (!tags) return null;
        for (var i = 0; i < tags.length; i++) {
            if (tags[i][0] === name && tags[i].length > 1) return tags[i][1];
        }
        return null;
    }

    function getImetaUrl(tags) {
        if (!tags) return null;
        for (var i = 0; i < tags.length; i++) {
            if (tags[i][0] !== 'imeta') continue;
            for (var j = 1; j < tags[i].length; j++) {
                var parts = tags[i][j].split(' ');
                if (parts[0] === 'url') return parts.slice(1).join(' ');
            }
        }
        return null;
    }

    function getImetaThumb(tags) {
        if (!tags) return null;
        for (var i = 0; i < tags.length; i++) {
            if (tags[i][0] !== 'imeta') continue;
            for (var j = 1; j < tags[i].length; j++) {
                var parts = tags[i][j].split(' ');
                if (parts[0] === 'image') return parts.slice(1).join(' ');
            }
        }
        return null;
    }

    function parseVideoEvent(evt) {
        var url = getImetaUrl(evt.tags) || getTagValue(evt.tags, 'url');
        var thumb = getImetaThumb(evt.tags) || getTagValue(evt.tags, 'thumb');
        var title = getTagValue(evt.tags, 'title') || evt.content || '';
        var dTag = getTagValue(evt.tags, 'd') || evt.id;

        return {
            id: evt.id,
            dTag: dTag,
            pubkey: evt.pubkey,
            url: url,
            thumb: thumb,
            title: title.slice(0, 120),
            createdAt: evt.created_at
        };
    }

    // =========================================================================
    // Relative time
    // =========================================================================

    function relativeTime(unixTimestamp) {
        var now = Math.floor(Date.now() / 1000);
        var diff = now - unixTimestamp;
        if (diff < 60) return 'just now';
        if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
        if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
        if (diff < 2592000) return Math.floor(diff / 86400) + 'd ago';
        if (diff < 31536000) return Math.floor(diff / 2592000) + 'mo ago';
        return Math.floor(diff / 31536000) + 'y ago';
    }

    // =========================================================================
    // DOM construction helpers (safe against XSS — no innerHTML for user data)
    // =========================================================================

    function el(tag, attrs, children) {
        var node = document.createElement(tag);
        if (attrs) {
            for (var key in attrs) {
                if (key === 'textContent') {
                    node.textContent = attrs[key];
                } else if (key === 'className') {
                    node.className = attrs[key];
                } else {
                    node.setAttribute(key, attrs[key]);
                }
            }
        }
        if (children) {
            for (var i = 0; i < children.length; i++) {
                if (typeof children[i] === 'string') {
                    node.appendChild(document.createTextNode(children[i]));
                } else if (children[i]) {
                    node.appendChild(children[i]);
                }
            }
        }
        return node;
    }

    // =========================================================================
    // Rendering (uses programmatic DOM construction to prevent XSS)
    // =========================================================================

    function renderProfile(profileEvt, npub) {
        var container = document.getElementById('embed-profile');
        if (!container) return;
        container.innerHTML = '';

        var name = 'Anonymous';
        var bio = '';
        var picture = '';

        if (profileEvt) {
            try {
                var meta = JSON.parse(profileEvt.content);
                name = meta.display_name || meta.name || 'Anonymous';
                bio = meta.about || '';
                picture = meta.picture || '';
            } catch (_) { /* ignore */ }
        }

        var profileUrl = 'https://divine.video/profile/' + encodeURIComponent(npub);
        var initial = name.charAt(0).toUpperCase();

        // Build avatar
        var avatarDiv = el('div', { className: 'embed-avatar' });
        if (picture) {
            var img = el('img', { src: picture, alt: '' });
            img.onerror = function () {
                avatarDiv.textContent = initial;
            };
            avatarDiv.appendChild(img);
        } else {
            avatarDiv.textContent = initial;
        }

        // Build profile info
        var infoChildren = [
            el('div', { className: 'embed-profile-name', textContent: name }),
        ];
        if (bio) {
            infoChildren.push(
                el('div', { className: 'embed-profile-bio', textContent: bio.slice(0, 120) })
            );
        }
        var infoDiv = el('div', { className: 'embed-profile-info' }, infoChildren);

        // Build link wrapper
        var link = el('a', {
            className: 'embed-profile',
            href: profileUrl,
            target: '_blank',
            rel: 'noopener noreferrer',
        }, [avatarDiv, infoDiv]);

        container.appendChild(link);
    }

    function renderVideos(videos, npub) {
        var container = document.getElementById('embed-videos');
        if (!container) return;
        container.innerHTML = '';

        if (videos.length === 0) {
            container.appendChild(
                el('div', { className: 'embed-empty', textContent: 'No videos yet' })
            );
            return;
        }

        for (var i = 0; i < videos.length; i++) {
            var v = parseVideoEvent(videos[i]);
            var videoUrl = 'https://divine.video/v/' + encodeURIComponent(v.dTag);

            // Build thumbnail
            var thumbWrapper = el('div', { className: 'embed-thumb-wrapper' });
            if (v.thumb) {
                var thumbImg = el('img', { src: v.thumb, alt: '', loading: 'lazy' });
                thumbImg.onerror = function () {
                    var fallback = el('div', { className: 'no-thumb' }, ['\u25B6']);
                    this.parentElement.replaceChild(fallback, this);
                };
                thumbWrapper.appendChild(thumbImg);
            } else {
                thumbWrapper.appendChild(
                    el('div', { className: 'no-thumb' }, ['\u25B6'])
                );
            }

            // Play overlay (static SVG — safe to use innerHTML for known constant)
            var playOverlay = el('div', { className: 'embed-play-overlay' });
            playOverlay.innerHTML = '<svg viewBox="0 0 24 24"><polygon points="8,5 19,12 8,19"/></svg>';
            thumbWrapper.appendChild(playOverlay);

            // Build video info
            var infoChildren = [];
            if (v.title) {
                infoChildren.push(
                    el('div', { className: 'embed-video-title', textContent: v.title })
                );
            }
            infoChildren.push(
                el('div', { className: 'embed-video-time', textContent: relativeTime(v.createdAt) })
            );
            var infoDiv = el('div', { className: 'embed-video-info' }, infoChildren);

            // Build card
            var link = el('a', {
                href: videoUrl,
                target: '_blank',
                rel: 'noopener noreferrer',
            }, [thumbWrapper, infoDiv]);

            container.appendChild(
                el('div', { className: 'embed-video-card' }, [link])
            );
        }
    }

    function renderCta(npub) {
        var container = document.getElementById('embed-cta');
        if (!container) return;
        container.innerHTML = '';

        var profileUrl = 'https://divine.video/profile/' + encodeURIComponent(npub);
        container.appendChild(
            el('a', {
                className: 'embed-cta',
                href: profileUrl,
                target: '_blank',
                rel: 'noopener noreferrer',
                textContent: 'View on Divine',
            })
        );
    }

    function showLoading() {
        var el = document.getElementById('embed-loading');
        if (el) el.classList.remove('hidden');
        var content = document.getElementById('embed-content');
        if (content) content.classList.add('hidden');
    }

    function hideLoading() {
        var el = document.getElementById('embed-loading');
        if (el) el.classList.add('hidden');
        var content = document.getElementById('embed-content');
        if (content) content.classList.remove('hidden');
    }

    function showError(message) {
        var container = document.getElementById('embed-loading');
        if (container) {
            container.innerHTML = '';
            container.appendChild(
                el('div', { className: 'embed-error' }, [
                    el('div', { className: 'embed-error-icon', textContent: '\u26A0' }),
                    el('div', { textContent: message }),
                ])
            );
        }
    }

    // =========================================================================
    // Main logic
    // =========================================================================

    function getParams() {
        var params = new URLSearchParams(window.location.search);
        return {
            npub: params.get('npub') || '',
            theme: params.get('theme') || 'dark',
            count: Math.min(Math.max(parseInt(params.get('count'), 10) || 1, 1), 5),
            autorefresh: (function () {
                var raw = parseInt(params.get('autorefresh'), 10);
                return isNaN(raw) ? 60 : Math.max(raw, 0);
            })()
        };
    }

    function applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme === 'light' ? 'light' : 'dark');
    }

    var refreshTimer = null;

    function loadContent(config) {
        var pubkeyHex = npubToHex(config.npub);
        if (!pubkeyHex) {
            showError('Invalid npub. Please provide a valid Nostr public key.');
            return Promise.resolve();
        }

        showLoading();

        return Promise.all([
            fetchProfile(pubkeyHex),
            fetchVideos(pubkeyHex, config.count)
        ]).then(function (results) {
            var profile = results[0];
            var videos = results[1];

            renderProfile(profile, config.npub);
            renderVideos(videos, config.npub);
            renderCta(config.npub);
            hideLoading();
        }).catch(function (err) {
            console.error('Embed load error:', err);
            showError('Could not load content. Please try again later.');
        });
    }

    function init() {
        var config = getParams();

        if (!config.npub) {
            showError('Missing npub parameter. Usage: embed?npub=npub1...');
            return;
        }

        applyTheme(config.theme);
        loadContent(config);

        // Auto-refresh
        if (config.autorefresh > 0) {
            if (refreshTimer) clearInterval(refreshTimer);
            refreshTimer = setInterval(function () {
                loadContent(config);
            }, config.autorefresh * 60 * 1000);
        }
    }

    // Start when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
