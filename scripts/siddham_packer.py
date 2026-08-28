# ============================================================================
# File:          siddham_packer.py
# Description:   Host Tensor Quantization & 128-bit Bus Serialization
#                Utility for Siddham NPU Architecture.
# ============================================================================

import numpy as np

class SiddhamTensorPacker:
    def __init__(self, array_n: int = 16):
        self.array_n = array_n
        self.bus_bytes = 16  # 128-bit wide bus = 16 Int8 bytes

    def quantize_int8(self, tensor: np.ndarray, scale: float = 1.0) -> np.ndarray:
        """Quantizes floating-point arrays to Int8 in range [-128, 127]."""
        scaled = np.round(tensor / scale)
        clamped = np.clip(scaled, -128, 127)
        return clamped.astype(np.int8)

    def pack_activations(self, matrix_a: np.ndarray) -> list[int]:
        """
        Packs Activation Matrix A columns into 128-bit words (Little-Endian).
        Systolic boundary expects Column k data packed at word index k.
        """
        matrix_a = np.asarray(matrix_a, dtype=np.int8)
        rows, cols = matrix_a.shape
        packed_words = []

        for c in range(cols):
            word = 0
            for r in range(rows):
                val = int(matrix_a[r, c]) & 0xFF
                word |= (val << (r * 8))
            packed_words.append(word)
        return packed_words

    def pack_weights(self, matrix_b: np.ndarray) -> list[int]:
        """
        Packs Weight Matrix B rows into 128-bit words (Little-Endian).
        Systolic boundary expects Row k data packed at word index k.
        """
        matrix_b = np.asarray(matrix_b, dtype=np.int8)
        rows, cols = matrix_b.shape
        packed_words = []

        for r in range(rows):
            word = 0
            for c in range(cols):
                val = int(matrix_b[r, c]) & 0xFF
                word |= (val << (c * 8))
            packed_words.append(word)
        return packed_words

    def unpack_results(self, packed_words: list[int], rows: int, cols: int) -> np.ndarray:
        """Unpacks 128-bit SRAM result words back into a 2D Int8 NumPy matrix."""
        result = np.zeros((rows, cols), dtype=np.int8)
        for r in range(rows):
            word = packed_words[r]
            for c in range(cols):
                val = (word >> (c * 8)) & 0xFF
                # Sign extension for 2's complement Int8
                signed_val = val if val < 128 else val - 256
                result[r, c] = signed_val
        return result

    def to_verilog_hex(self, words: list[int]) -> list[str]:
        """Formats 128-bit packed integers into Verilog literal strings."""
        return [f"128'h{w:032x}" for w in words]

    def to_binary_stream(self, words: list[int]) -> bytes:
        """Converts packed words to raw byte stream for DMA transfers."""
        stream = bytearray()
        for w in words:
            stream.extend(w.to_bytes(self.bus_bytes, byteorder='little'))
        return bytes(stream)


if __name__ == "__main__":
    # Demo matching verified 2x2 test matrices:
    # A = [[2, 4], [3, 1]]
    # B = [[5, 7], [6, 8]]
    A = np.array([[2, 4], [3, 1]], dtype=np.int8)
    B = np.array([[5, 7], [6, 8]], dtype=np.int8)

    packer = SiddhamTensorPacker(array_n=2)

    words_a = packer.pack_activations(A)
    words_b = packer.pack_weights(B)

    print("=== Activation Stream A (Columns Packed) ===")
    for i, hex_str in enumerate(packer.to_verilog_hex(words_a)):
        print(f"Col {i}: {hex_str}")

    print("\n=== Weight Stream B (Rows Packed) ===")
    for i, hex_str in enumerate(packer.to_verilog_hex(words_b)):
        print(f"Row {i}: {hex_str}")

    # Simulated output validation for C = A x B
    raw_sim_output = [0x2e22, 0x1d15]
    tensor_c = packer.unpack_results(raw_sim_output, rows=2, cols=2)

    print("\n=== Unpacked Result Tensor C ===")
    print(tensor_c)
