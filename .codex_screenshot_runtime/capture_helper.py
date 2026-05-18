import base64
import json
import os
import shutil
import socket
import struct
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(r'C:\Users\daomi\develop\project\workout_track')
OUT = ROOT / 'ui_audit_screenshots_2026-05-17'
RUNTIME = ROOT / '.codex_screenshot_runtime'
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
URL = 'http://127.0.0.1:51738'
WIDTH = 390
HEIGHT = 844

class WS:
    def __init__(self, url):
        rest = url[5:]
        hostport, path = rest.split('/', 1)
        host, port = hostport.split(':')
        self.s = socket.create_connection((host, int(port)), timeout=10)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f'GET /{path} HTTP/1.1\r\n'
            f'Host: {hostport}\r\n'
            'Upgrade: websocket\r\n'
            'Connection: Upgrade\r\n'
            f'Sec-WebSocket-Key: {key}\r\n'
            'Sec-WebSocket-Version: 13\r\n\r\n'
        )
        self.s.sendall(req.encode())
        data = b''
        while b'\r\n\r\n' not in data:
            data += self.s.recv(4096)
        if b' 101 ' not in data.split(b'\r\n', 1)[0]:
            raise RuntimeError(data[:200])

    def send(self, obj):
        payload = json.dumps(obj).encode()
        n = len(payload)
        header = bytearray([0x81])
        if n < 126:
            header.append(0x80 | n)
        elif n < 65536:
            header.append(0x80 | 126)
            header.extend(struct.pack('!H', n))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack('!Q', n))
        mask = os.urandom(4)
        header.extend(mask)
        self.s.sendall(bytes(header) + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))

    def recv(self):
        chunks = []
        while True:
            b1 = self.s.recv(1)[0]
            b2 = self.s.recv(1)[0]
            opcode = b1 & 15
            n = b2 & 127
            if n == 126:
                n = struct.unpack('!H', self.s.recv(2))[0]
            elif n == 127:
                n = struct.unpack('!Q', self.s.recv(8))[0]
            mask = b''
            if b2 & 128:
                mask = self.s.recv(4)
            data = b''
            while len(data) < n:
                data += self.s.recv(n - len(data))
            if b2 & 128:
                data = bytes(c ^ mask[i % 4] for i, c in enumerate(data))
            if opcode == 8:
                raise EOFError('websocket closed')
            if opcode in (0, 1):
                chunks.append(data)
            if b1 & 128:
                return json.loads(b''.join(chunks).decode(errors='replace'))

class CDP:
    def __init__(self, ws_url):
        self.ws = WS(ws_url)
        self.next_id = 0
    def call(self, method, params=None, timeout=30):
        self.next_id += 1
        call_id = self.next_id
        self.ws.send({'id': call_id, 'method': method, 'params': params or {}})
        end = time.time() + timeout
        while time.time() < end:
            msg = self.ws.recv()
            if msg.get('id') == call_id:
                if 'error' in msg:
                    raise RuntimeError(f'{method}: {msg["error"]}')
                return msg.get('result', {})
        raise TimeoutError(method)

class AppCapture:
    def __init__(self, port=9240, clean_profile=True):
        self.port = port
        self.profile = RUNTIME / f'audit_chrome_profile_{port}'
        if clean_profile and self.profile.exists():
            shutil.rmtree(self.profile)
        self.proc = subprocess.Popen([
            CHROME,
            '--headless=new',
            f'--remote-debugging-port={port}',
            f'--user-data-dir={self.profile}',
            '--disable-gpu',
            '--no-first-run',
            '--no-default-browser-check',
            'about:blank',
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(120):
            try:
                urllib.request.urlopen(f'http://127.0.0.1:{port}/json/version', timeout=1).read()
                break
            except Exception:
                time.sleep(0.1)
        req = urllib.request.Request(
            f'http://127.0.0.1:{port}/json/new?{urllib.parse.quote(URL, safe=":/")}',
            method='PUT',
        )
        info = json.loads(urllib.request.urlopen(req, timeout=5).read())
        self.c = CDP(info['webSocketDebuggerUrl'])
        self.c.call('Page.enable')
        self.c.call('Runtime.enable')
        self.c.call('Emulation.setDeviceMetricsOverride', {
            'width': WIDTH,
            'height': HEIGHT,
            'deviceScaleFactor': 1,
            'mobile': True,
        })
        self.c.call('Page.navigate', {'url': URL})
        time.sleep(12)
    def close(self):
        self.proc.terminate()
    def shot(self, name, delay=0.8):
        time.sleep(delay)
        data = self.c.call('Page.captureScreenshot', {
            'format': 'png',
            'captureBeyondViewport': False,
        }, timeout=30)['data']
        path = OUT / f'{name}.png'
        path.write_bytes(base64.b64decode(data))
        print(path.name)
    def tap(self, x, y, delay=0.7):
        self.c.call('Input.dispatchTouchEvent', {
            'type': 'touchStart',
            'touchPoints': [{'x': x, 'y': y, 'radiusX': 2, 'radiusY': 2, 'force': 1, 'id': 1}],
        })
        time.sleep(0.05)
        self.c.call('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
        time.sleep(delay)
    def wheel(self, delta_y, x=350, y=500, delay=0.5):
        self.c.call('Input.dispatchMouseEvent', {
            'type': 'mouseWheel', 'x': x, 'y': y, 'deltaY': delta_y, 'deltaX': 0,
        })
        time.sleep(delay)
    def drag(self, x1, y1, x2, y2, steps=8, delay=0.6):
        self.c.call('Input.dispatchTouchEvent', {
            'type': 'touchStart',
            'touchPoints': [{'x': x1, 'y': y1, 'radiusX': 3, 'radiusY': 3, 'force': 1, 'id': 1}],
        })
        for i in range(1, steps + 1):
            x = x1 + (x2 - x1) * i / steps
            y = y1 + (y2 - y1) * i / steps
            self.c.call('Input.dispatchTouchEvent', {
                'type': 'touchMove',
                'touchPoints': [{'x': x, 'y': y, 'radiusX': 3, 'radiusY': 3, 'force': 1, 'id': 1}],
            })
            time.sleep(0.03)
        self.c.call('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
        time.sleep(delay)
    def text(self, value, delay=0.4):
        self.c.call('Input.insertText', {'text': value})
        time.sleep(delay)
    def key(self, key, delay=0.2):
        self.c.call('Input.dispatchKeyEvent', {'type': 'keyDown', 'key': key})
        self.c.call('Input.dispatchKeyEvent', {'type': 'keyUp', 'key': key})
        time.sleep(delay)
    def select_all(self):
        self.c.call('Input.dispatchKeyEvent', {'type':'rawKeyDown','key':'Control','code':'ControlLeft','windowsVirtualKeyCode':17,'modifiers':2})
        self.c.call('Input.dispatchKeyEvent', {'type':'rawKeyDown','key':'a','code':'KeyA','windowsVirtualKeyCode':65,'modifiers':2})
        self.c.call('Input.dispatchKeyEvent', {'type':'keyUp','key':'a','code':'KeyA','windowsVirtualKeyCode':65,'modifiers':2})
        self.c.call('Input.dispatchKeyEvent', {'type':'keyUp','key':'Control','code':'ControlLeft','windowsVirtualKeyCode':17})
        time.sleep(0.1)

if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    print(OUT)
