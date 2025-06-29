#!/usr/bin/env python3
"""
Test script to verify if profile events are being published and stored correctly
"""
import websocket
import json
import time
import threading

def on_message(ws, message):
    try:
        data = json.loads(message)
        print(f"📨 Received: {data}")
        
        # Look for profile events (kind 0)
        if data[0] == "EVENT" and len(data) >= 3:
            event = data[2]
            if event.get("kind") == 0:
                print(f"👤 Profile event found!")
                print(f"   - ID: {event['id']}")
                print(f"   - Pubkey: {event['pubkey'][:16]}...")
                print(f"   - Content: {event['content'][:100]}...")
                print(f"   - Created: {time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(event['created_at']))}")
                
    except Exception as e:
        print(f"❌ Error parsing message: {e}")

def on_error(ws, error):
    print(f"❌ WebSocket error: {error}")

def on_close(ws, close_status_code, close_msg):
    print("🔌 WebSocket connection closed")

def on_open(ws):
    print("✅ Connected to vine.hol.is")
    
    # Subscribe to recent profile events (kind 0) from last hour
    current_time = int(time.time())
    one_hour_ago = current_time - 3600
    
    subscription = [
        "REQ",
        "test_profiles",
        {
            "kinds": [0],
            "since": one_hour_ago,
            "limit": 50
        }
    ]
    
    print(f"📡 Subscribing to recent profile events...")
    ws.send(json.dumps(subscription))

if __name__ == "__main__":
    print("🔍 Testing vine.hol.is relay for recent profile events...")
    print("This will show any profile events published in the last hour")
    print("")
    
    websocket.enableTrace(False)
    ws = websocket.WebSocketApp(
        "wss://vine.hol.is",
        on_open=on_open,
        on_message=on_message,
        on_error=on_error,
        on_close=on_close
    )
    
    try:
        ws.run_forever()
    except KeyboardInterrupt:
        print("\n👋 Interrupted by user")
        ws.close()