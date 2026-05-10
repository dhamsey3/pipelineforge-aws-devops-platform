from flask import Flask, jsonify, request
import os

app = Flask(__name__)

@app.route('/')
def health():
    return jsonify({'status': 'ok'})

@app.route('/items', methods=['GET'])
def get_items():
    # Placeholder for DynamoDB integration
    return jsonify({'items': []})

@app.route('/items', methods=['POST'])
def create_item():
    data = request.json
    # Placeholder for DynamoDB integration
    return jsonify({'item': data}), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
