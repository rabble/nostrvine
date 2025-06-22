// ABOUTME: OpenVine landing page JavaScript for interactivity
// ABOUTME: Handles channel clicks, search, and dynamic content loading


document.addEventListener('DOMContentLoaded', function() {
    // Channel categories mapping
    const channelCategories = {
        '🎬': 'Entertainment',
        '🎵': 'Music',
        '😄': 'Comedy',
        '🌟': 'Popular',
        '🎨': 'Art',
        '🔥': 'Trending',
        '🎮': 'Gaming',
        '💥': 'Action',
        '🌈': 'Creative',
        '🎯': 'Sports',
        '⚡': 'Tech',
        '🎭': 'Drama',
        '🏀': 'Basketball',
        '🍕': 'Food',
        '🎸': 'Music',
        '🚗': 'Cars',
        '🍔': 'Food',
        '🌮': 'Food',
        '💚': 'Nature',
        '🎪': 'Entertainment',
        '⚠️': 'Extreme'
    };

    // Handle channel clicks
    const channelItems = document.querySelectorAll('.channel-item');
    channelItems.forEach(item => {
        item.addEventListener('click', function() {
            const icon = this.querySelector('.channel-icon').textContent;
            const category = channelCategories[icon] || 'Unknown';
            console.log(`Channel clicked: ${category}`);
            
            // Add ripple effect
            this.style.transform = 'scale(0.95)';
            setTimeout(() => {
                this.style.transform = 'scale(1.05)';
                setTimeout(() => {
                    this.style.transform = 'scale(1)';
                }, 150);
            }, 100);
            
            // In a real app, this would load videos for this channel
            showNotification(`Loading ${category} videos...`);
        });
    });

    // Handle search
    const searchInput = document.querySelector('.search-input');
    const searchButton = document.querySelector('.search-button');
    
    function performSearch() {
        const query = searchInput.value.trim();
        if (query) {
            console.log(`Searching for: ${query}`);
            showNotification(`Searching for "${query}"...`);
            // In a real app, this would perform actual search
        }
    }
    
    searchButton.addEventListener('click', performSearch);
    searchInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            performSearch();
        }
    });

    // Handle platform buttons
    const navButtons = document.querySelectorAll('.nav-button[data-platform]');
    navButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            e.preventDefault();
            const platform = this.dataset.platform;
            
            // Remove active class from all platform buttons
            navButtons.forEach(btn => btn.classList.remove('active'));
            // Add active class to clicked button
            this.classList.add('active');
            
            // Platform-specific actions
            switch(platform) {
                case 'ios':
                    window.location.href = 'ios.html';
                    break;
                case 'android':
                    window.location.href = 'android.html';
                    break;
            }
        });
    });

    // Handle viner card clicks
    const vinerCards = document.querySelectorAll('.viner-card');
    vinerCards.forEach(card => {
        card.addEventListener('click', function() {
            const vinerName = this.querySelector('.viner-name').textContent;
            console.log(`Viner clicked: ${vinerName}`);
            showNotification(`Loading ${vinerName}'s profile...`);
        });
    });

    // Handle popular item clicks
    const popularItems = document.querySelectorAll('.popular-item');
    popularItems.forEach(item => {
        item.addEventListener('click', function() {
            const title = this.querySelector('h4').textContent;
            console.log(`Popular video clicked: ${title}`);
            showNotification(`Loading video: ${title}`);
        });
    });

    // Notification function
    function showNotification(message) {
        // Remove existing notification if any
        const existingNotif = document.querySelector('.notification');
        if (existingNotif) {
            existingNotif.remove();
        }
        
        // Create notification
        const notif = document.createElement('div');
        notif.className = 'notification';
        notif.textContent = message;
        notif.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background-color: #0ae68a;
            color: white;
            padding: 1rem 2rem;
            border-radius: 25px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            z-index: 1000;
            animation: slideIn 0.3s ease-out;
        `;
        
        // Add animation
        const style = document.createElement('style');
        style.textContent = `
            @keyframes slideIn {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
        `;
        document.head.appendChild(style);
        
        document.body.appendChild(notif);
        
        // Remove after 3 seconds
        setTimeout(() => {
            notif.style.animation = 'slideOut 0.3s ease-in';
            notif.style.animationFillMode = 'forwards';
            
            const slideOutStyle = document.createElement('style');
            slideOutStyle.textContent = `
                @keyframes slideOut {
                    from {
                        transform: translateX(0);
                        opacity: 1;
                    }
                    to {
                        transform: translateX(100%);
                        opacity: 0;
                    }
                }
            `;
            document.head.appendChild(slideOutStyle);
            
            setTimeout(() => {
                notif.remove();
            }, 300);
        }, 3000);
    }

    // Simulate loading animation for video placeholder
    const loadingText = document.querySelector('.loading-text');
    if (loadingText) {
        const messages = [
            'Loading amazing vines...',
            'Finding the best content...',
            'Almost there...',
            'Get ready to loop!'
        ];
        let messageIndex = 0;
        
        setInterval(() => {
            messageIndex = (messageIndex + 1) % messages.length;
            loadingText.textContent = messages[messageIndex];
        }, 2000);
    }

    // Add some life to the page with random animations
    function addRandomAnimation() {
        const channels = Array.from(channelItems);
        if (channels.length > 0) {
            const randomChannel = channels[Math.floor(Math.random() * channels.length)];
            randomChannel.style.animation = 'bounce 0.5s ease-in-out';
            
            const bounceStyle = document.createElement('style');
            bounceStyle.textContent = `
                @keyframes bounce {
                    0%, 100% { transform: scale(1); }
                    50% { transform: scale(1.1); }
                }
            `;
            document.head.appendChild(bounceStyle);
            
            setTimeout(() => {
                randomChannel.style.animation = '';
            }, 500);
        }
    }
    
    // Add random animation every 5 seconds
    setInterval(addRandomAnimation, 5000);
    
    // Log that the page is ready
    console.log('OpenVine landing page loaded successfully!');
    
    // Matrix-style view counter animation
    function animateViewCounts() {
        const viewElements = document.querySelectorAll('.vine-stats .views');
        
        viewElements.forEach(element => {
            // Random chance to update each counter
            if (Math.random() > 0.7) {
                const currentText = element.textContent;
                const match = currentText.match(/[\d.]+/);
                if (match) {
                    let currentNum = parseFloat(match[0]);
                    // Random increment between 0.1 and 2.5
                    const increment = (Math.random() * 2.4 + 0.1).toFixed(1);
                    currentNum = parseFloat(currentNum) + parseFloat(increment);
                    
                    // Format with K suffix
                    element.textContent = `👁️ ${currentNum.toFixed(1)}K views`;
                    
                    // Add glitch effect
                    element.style.color = '#0ae68a';
                    element.style.textShadow = '0 0 3px #0ae68a';
                    
                    setTimeout(() => {
                        element.style.color = '#666';
                        element.style.textShadow = 'none';
                    }, 200);
                }
            }
        });
    }
    
    // Start the animation
    setInterval(animateViewCounts, 500);
    
    // Initial animation
    animateViewCounts();
});

// All video functionality moved to vine-player.js