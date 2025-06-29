#!/usr/bin/env node

// ABOUTME: Simple test script for vine.hol.is relay without authentication
// ABOUTME: Tests if we can read events without NIP-42 auth

const WebSocket = require('ws');

async function testVineRelaySimple() {
    console.log('🍇 Testing vine.hol.is relay (no auth)...\n');
    
    // Connect to relay
    console.log('Connecting to wss://vine.hol.is...');
    const ws = new WebSocket('wss://vine.hol.is');
    
    let messageCount = 0;
    let eventCount = 0;
    
    ws.on('open', () => {
        console.log('✅ Connected to relay\n');
        
        // Try different queries without authentication
        const queries = [
            {
                name: 'Basic Recent Events',
                query: {
                    limit: 5,
                    since: Math.floor(Date.now() / 1000) - (24 * 60 * 60) // Last 24 hours
                }
            },
            {
                name: 'Kind 22 (Short Videos)',
                query: {
                    kinds: [22],
                    limit: 10,
                    since: Math.floor(Date.now() / 1000) - (30 * 24 * 60 * 60) // Last 30 days
                }
            },
            {
                name: 'Groups Events (Kind 9/11)',
                query: {
                    kinds: [9, 11],
                    limit: 10
                }
            },
            {
                name: 'All Events',
                query: {
                    limit: 20
                }
            }
        ];
        
        // Send queries
        queries.forEach((test, i) => {
            setTimeout(() => {
                const subId = `test_${i}`;
                console.log(`📤 [${i + 1}/${queries.length}] Testing: ${test.name}`);
                console.log(`   Query:`, JSON.stringify(test.query));
                
                const reqMessage = ['REQ', subId, test.query];
                ws.send(JSON.stringify(reqMessage));
            }, i * 2000); // 2 second delay between queries
        });
        
        // Close after all tests
        setTimeout(() => {
            console.log(`\n🏁 Test completed - found ${eventCount} events total`);
            ws.close();
        }, queries.length * 2000 + 5000);
    });
    
    ws.on('message', (data) => {
        messageCount++;
        const message = JSON.parse(data.toString());
        console.log(`📥 [${messageCount}] ${message[0]}:`, 
                   message[0] === 'EVENT' ? `Kind ${message[2]?.kind} - ${message[2]?.content?.slice(0, 50) || '(no content)'}...` :
                   message[0] === 'EOSE' ? `End of ${message[1]}` :
                   message[0] === 'AUTH' ? `Challenge: ${message[1]}` :
                   message[0] === 'NOTICE' ? message[1] :
                   message[0] === 'CLOSED' ? `${message[1]} - ${message[2]}` :
                   JSON.stringify(message.slice(1)));
        
        if (message[0] === 'EVENT') {
            eventCount++;
            const event = message[2];
            console.log(`   📺 Kind ${event.kind} by ${event.pubkey.slice(0, 16)}... at ${new Date(event.created_at * 1000).toISOString()}`);
            if (event.tags && event.tags.length > 0) {
                console.log(`   🏷️  Tags: ${JSON.stringify(event.tags.slice(0, 3))}`);
            }
        }
    });
    
    ws.on('error', (error) => {
        console.error('❌ WebSocket error:', error.message);
    });
    
    ws.on('close', (code, reason) => {
        console.log(`👋 WebSocket closed (${code}): ${reason || 'No reason given'}`);
        process.exit(0);
    });
}

// Run the test
testVineRelaySimple().catch(console.error);