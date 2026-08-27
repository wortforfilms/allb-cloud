import socket
import json
import time
from typing import Dict, Any

class MaataaEdgeClient:
    def __init__(self, socket_path: str = "/var/run/maataa.sock"):
        self.socket_path = socket_path

    def _send_ipc(self, request: Dict[str, Any]) -> Dict[str, Any]:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            client.connect(self.socket_path)
            client.sendall(json.dumps(request).encode('utf-8'))
            data = client.recv(8192)
            return json.loads(data.decode('utf-8'))
        finally:
            client.close()

    def evaluate_sandhi(self, left_stem: str, right_stem: str) -> Dict[str, Any]:
        req = {
            "command": "eval_sandhi",
            "payload_left": left_stem,
            "payload_right": right_stem
        }
        return self._send_ipc(req)

# Example Usage
if __name__ == "__main__":
    sdk = MaataaEdgeClient()
    res = sdk.evaluate_sandhi("𑀮𑀺", "𑀧𑀺")
    print(f"SBC Response Status: {res['status']} | Latency: {res['latency_ms']:.3f}ms")
    print(f"Tokens: {res['result']}")