"""
Barcode Decoder API - Using zxing-cpp
ZXing-cpp is a C++ port of ZXing, very fast and accurate

Requirements:
pip install flask pillow zxing-cpp
"""

from flask import Flask, request, jsonify
from PIL import Image
import io
import os
from datetime import datetime
import zxingcpp

app = Flask(__name__)

print("[INFO] Using zxing-cpp for barcode decoding")

@app.route('/decode-barcode', methods=['POST'])
def decode_barcode():
    """
    Nhận ảnh từ ESP32 và decode barcode
    """
    try:
        # Kiểm tra có file không
        if 'image' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No image provided'
            }), 400
        
        file = request.files['image']
        
        # Đọc ảnh
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes))
        
        # Debug: Save ảnh
        debug_dir = 'debug_images'
        if not os.path.exists(debug_dir):
            os.makedirs(debug_dir)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        debug_path = os.path.join(debug_dir, f'barcode_{timestamp}.jpg')
        image.save(debug_path)
        print(f"[DEBUG] Saved image to {debug_path}")
        print(f"[DEBUG] Image size: {image.size}, mode: {image.mode}")
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Decode barcode using zxing-cpp
        print("[DECODE] Attempting to decode with zxing-cpp...")
        
        results = zxingcpp.read_barcodes(image)
        
        print(f"[DECODE] Found {len(results)} barcode(s)")
        
        if len(results) > 0:
            # Get first barcode
            result = results[0]
            barcode_data = result.text
            barcode_type = result.format.name
            
            print(f"[SUCCESS] Found {barcode_type}: {barcode_data}")
            print(f"[INFO] Position: {result.position}")
            print(f"[INFO] Orientation: {result.orientation}")
            
            return jsonify({
                'success': True,
                'barcode': barcode_data,
                'type': barcode_type,
                'decoder': 'zxing-cpp',
                'confidence': 'high'
            })
        
        # No barcode found
        print("[FAILED] No barcode detected")
        return jsonify({
            'success': False,
            'error': 'No barcode found',
            'message': 'Không tìm thấy barcode. Thử: 1) Đưa barcode gần hơn (15cm), 2) Đảm bảo đủ ánh sáng, 3) Barcode phải rõ ràng và không bị che khuất',
            'decoder': 'zxing-cpp'
        })
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'ok', 
        'decoder': 'zxing-cpp'
    })

if __name__ == '__main__':
    print("=" * 60)
    print("Barcode Decoder API - ZXing-cpp")
    print("=" * 60)
    print("")
    print("Supported formats:")
    print("  - EAN-13, EAN-8, UPC-A, UPC-E")
    print("  - Code 128, Code 39, Code 93")
    print("  - QR Code, Data Matrix, PDF417")
    print("  - Aztec, MaxiCode, RSS")
    print("=" * 60)
    print("Listening on http://0.0.0.0:5000")
    print("Endpoint: POST /decode-barcode")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5000, debug=True)
