"""
Barcode Decoder API - OpenCV Version
Nhận ảnh từ ESP32 → Decode barcode → Trả về barcode string

Requirements:
pip install flask pillow opencv-python
"""

from flask import Flask, request, jsonify
from PIL import Image
import io
import cv2
import numpy as np

# Try pyzbar first, fallback to OpenCV
try:
    from pyzbar.pyzbar import decode as pyzbar_decode
    USE_PYZBAR = True
    print("[INFO] Using pyzbar for barcode decoding")
except ImportError:
    USE_PYZBAR = False
    print("[INFO] pyzbar not available, using OpenCV barcode detector")
    # OpenCV barcode detector
    barcode_detector = cv2.barcode.BarcodeDetector()

app = Flask(__name__)

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
        
        # Debug: Save ảnh để kiểm tra
        import os
        debug_dir = 'debug_images'
        if not os.path.exists(debug_dir):
            os.makedirs(debug_dir)
        
        from datetime import datetime
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        debug_path = os.path.join(debug_dir, f'barcode_{timestamp}.jpg')
        image.save(debug_path)
        print(f"[DEBUG] Saved image to {debug_path}")
        
        # Convert sang numpy array cho OpenCV
        img_array = np.array(image)
        
        print(f"[DEBUG] Image shape: {img_array.shape}, dtype: {img_array.dtype}")
        
        # Decode barcode
        if USE_PYZBAR:
            # Dùng pyzbar
            barcodes = pyzbar_decode(img_array)
            
            if len(barcodes) == 0:
                return jsonify({
                    'success': False,
                    'error': 'No barcode found',
                    'message': 'Không tìm thấy barcode trong ảnh'
                })
            
            barcode = barcodes[0]
            barcode_data = barcode.data.decode('utf-8')
            barcode_type = barcode.type
        else:
            # Dùng OpenCV
            retval, decoded_info, decoded_type = barcode_detector.detectAndDecode(img_array)
            
            if not retval or len(decoded_info) == 0:
                return jsonify({
                    'success': False,
                    'error': 'No barcode found',
                    'message': 'Không tìm thấy barcode trong ảnh'
                })
            
            barcode_data = decoded_info[0] if isinstance(decoded_info, (list, tuple)) else decoded_info
            barcode_type = decoded_type[0] if isinstance(decoded_type, (list, tuple)) and len(decoded_type) > 0 else 'UNKNOWN'
        
        print(f"[DECODE] Found {barcode_type}: {barcode_data}")
        
        return jsonify({
            'success': True,
            'barcode': barcode_data,
            'type': barcode_type
        })
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    print("=" * 50)
    print("Barcode Decoder API")
    print("=" * 50)
    print("Listening on http://0.0.0.0:5000")
    print("Endpoint: POST /decode-barcode")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=True)
