#!/usr/bin/env node

// ABOUTME: Test script for vine.hol.is relay authentication and query capabilities
// ABOUTME: Tests NIP-42 auth and searches for Kind 22 events

const WebSocket = require('ws');
const crypto = require('crypto');
const { schnorr, utils, etc } = require('@noble/secp256k1');

// Proper secp256k1 implementation using noble library
function generateKeyPair() {
    const privateKey = utils.randomPrivateKey();
    const publicKey = schnorr.getPublicKey(privateKey);
    
    return { 
        privateKey: etc.bytesToHex(privateKey),
        publicKey: etc.bytesToHex(publicKey)
    };
}

async function signEvent(event, privateKeyHex) {
    // Create serialized event for signing
    const serialized = JSON.stringify([
        0, // Reserved
        event.pubkey,
        event.created_at,
        event.kind,
        event.tags,
        event.content
    ]);
    
    // Hash the serialized event
    const hash = crypto.createHash('sha256').update(serialized).digest();
    event.id = etc.bytesToHex(hash);
    
    // Sign with proper secp256k1 Schnorr signature
    const signature = await schnorr.sign(hash, privateKeyHex);
    event.sig = etc.bytesToHex(signature);
    
    return event;
}

async function testVineRelay() {
    console.log('🍇 Testing vine.hol.is relay...\n');
    
    // Generate disposable key pair
    const { privateKey, publicKey } = generateKeyPair();
    console.log(`Generated keypair:`);
    console.log(`Private: ${privateKey}`);
    console.log(`Public:  ${publicKey}\n`);
    
    // Connect to relay
    console.log('Connecting to wss://vine.hol.is...');
    const ws = new WebSocket('wss://vine.hol.is');
    
    let isAuthenticated = false;
    let messageCount = 0;
    
    ws.on('open', () => {
        console.log('✅ Connected to relay, waiting for AUTH challenge...\n');
    });
    
    ws.on('message', async (data) => {
        messageCount++;
        const message = JSON.parse(data.toString());
        console.log(`📥 [${messageCount}] Received:`, JSON.stringify(message, null, 2));
        
        const [type, ...args] = message;
        
        switch (type) {
            case 'AUTH':
                console.log('\n🔐 Handling AUTH challenge...');
                const challenge = args[0];
                
                // Create AUTH event
                const authEvent = {
                    kind: 22242,
                    pubkey: publicKey,
                    created_at: Math.floor(Date.now() / 1000),
                    tags: [
                        ['relay', 'wss://vine.hol.is'],
                        ['challenge', challenge]
                    ],
                    content: ''
                };
                
                // Sign and send AUTH response
                const signedEvent = await signEvent(authEvent, privateKey);
                const authMessage = ['AUTH', signedEvent];
                
                console.log('📤 Sending AUTH response:', JSON.stringify(authMessage, null, 2));
                ws.send(JSON.stringify(authMessage));
                break;
                
            case 'OK':
                const [eventId, success, responseMessage] = args;
                if (success) {
                    console.log(`✅ Event accepted: ${eventId}`);
                    if (!isAuthenticated) {
                        isAuthenticated = true;
                        console.log('🎉 Authentication successful!\n');
                        
                        // Now test different queries
                        await testQueries(ws);
                    }
                } else {
                    console.log(`❌ Event rejected: ${eventId} - ${responseMessage}`);
                }
                break;
                
            case 'EVENT':
                const [subscriptionId, event] = args;
                console.log(`📺 Found event (Kind ${event.kind}): ${event.content || '(no content)'}`);
                console.log(`   Author: ${event.pubkey.slice(0, 16)}...`);
                console.log(`   Tags: ${JSON.stringify(event.tags)}`);
                break;
                
            case 'EOSE':
                console.log(`✅ End of stored events for subscription: ${args[0]}\n`);
                break;
                
            case 'NOTICE':
                console.log(`📢 NOTICE: ${args[0]}`);
                break;
                
            case 'CLOSED':
                console.log(`🚫 Subscription closed: ${args[0]} - ${args[1]}`);
                break;
                
            default:
                console.log(`❓ Unknown message type: ${type}`);
        }
    });
    
    ws.on('error', (error) => {
        console.error('❌ WebSocket error:', error);
    });
    
    ws.on('close', () => {
        console.log('👋 WebSocket closed');
        process.exit(0);
    });
    
    // Test different query types
    async function testQueries(ws) {
        console.log('🔍 Testing different query types...\n');
        
        const queries = [
            {
                name: 'Basic Recent Events',
                query: {
                    limit: 10,
                    since: Math.floor(Date.now() / 1000) - (24 * 60 * 60) // Last 24 hours
                }
            },
            {
                name: 'Kind 22 (Short Videos)',
                query: {
                    kinds: [22],
                    limit: 50,
                    since: Math.floor(Date.now() / 1000) - (30 * 24 * 60 * 60) // Last 30 days
                }
            },
            {
                name: 'Search Query (NIP-50)',
                query: {
                    search: 'vine',
                    limit: 20
                }
            },
            {
                name: 'All Kinds Test',
                query: {
                    kinds: [0, 1, 3, 6, 7, 22, 30023],
                    limit: 20,
                    since: Math.floor(Date.now() / 1000) - (7 * 24 * 60 * 60) // Last 7 days
                }
            }
        ];
        
        for (let i = 0; i < queries.length; i++) {
            const { name, query } = queries[i];
            const subId = `test_${Date.now()}_${i}`;
            
            console.log(`📤 [${i + 1}/${queries.length}] Testing: ${name}`);
            console.log(`   Query:`, JSON.stringify(query, null, 2));
            
            const reqMessage = ['REQ', subId, query];
            ws.send(JSON.stringify(reqMessage));
            
            // Wait between queries
            if (i < queries.length - 1) {
                await new Promise(resolve => setTimeout(resolve, 3000));
            }
        }
        
        // Close after all tests
        setTimeout(() => {
            console.log('\n🏁 All tests completed');
            ws.close();
        }, 10000);
    }
}

// Run the test
testVineRelay().catch(console.error);