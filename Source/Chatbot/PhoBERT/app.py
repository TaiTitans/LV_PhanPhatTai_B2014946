import asyncio
import aiohttp
from flask import Flask, request, jsonify
import h5py
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
import torch
from transformers import AutoModel, AutoTokenizer
import sys
import logging
import requests
import os
from dotenv import load_dotenv
import re
# Load biến môi trường từ file .env
load_dotenv()

# Lấy API key và CSE ID từ biến môi trường
api_key = os.getenv('API_KEY')
cse_id = os.getenv('CSE_ID')
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding='utf-8')
else:
    sys.stdout = open(sys.stdout.fileno(), mode='w', encoding='utf-8', buffering=1)

# Khởi tạo Flask app
app = Flask(__name__)

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Tải PhoBERT model và tokenizer từ Hugging Face
try:
    phobert = AutoModel.from_pretrained("vinai/phobert-base-v2")
    tokenizer = AutoTokenizer.from_pretrained("vinai/phobert-base-v2")
except Exception as e:
    logger.error(f"Không thể tải PhoBERT: {str(e)}")
    sys.exit(1)

# Hàm bất đồng bộ tìm kiếm thông tin từ Google bằng Google Custom Search API
async def google_search(query, api_key, cse_id, num_results=5):
    url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "q": query,
        "cx": cse_id,  # Custom Search Engine ID
        "key": api_key,
        "num": num_results
    }
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(url, params=params, timeout=5) as response:
                results = await response.json()
                return results.get('items', [])
        except asyncio.TimeoutError:
            logger.error("Google Custom Search API request timed out")
            return []

\
# Hàm sinh câu trả lời từ Google Search
def generate_response_from_google_results(search_results):
    combined_text = " ".join([result['snippet'] for result in search_results if 'snippet' in result])

    combined_text = re.sub(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s\d{1,2},\s\d{4}\b', '', combined_text)
    
    # Loại bỏ các khoảng trắng dư thừa
    combined_text = re.sub(r'\s+', ' ', combined_text).strip()
    
    return combined_text if combined_text else "Xin lỗi, tôi không tìm thấy thông tin phù hợp."

# Hàm load dữ liệu từ file h5
def load_data():
    try:
        with h5py.File('chatbot_data_phobert_v2.h5', 'r') as h5f:
            questions = [q.decode('utf-8') for q in h5f['questions'][:]]
            answers = [a.decode('utf-8') for a in h5f['answers'][:]]
            question_embeddings = np.array(h5f['question_embeddings'][:], dtype=np.float32)
        return questions, answers, question_embeddings
    except Exception as e:
        logger.error(f"Không thể tải dữ liệu từ file H5: {str(e)}")
        sys.exit(1)

# Tải dữ liệu từ file H5
questions, answers, question_embeddings = load_data()

# Hàm lấy embedding từ PhoBERT
def get_phobert_embedding(text):
    tokens = tokenizer(text, return_tensors='pt', padding=True, truncation=True, max_length=256)
    with torch.no_grad():
        outputs = phobert(**tokens)
    return outputs.last_hidden_state.mean(dim=1).squeeze().numpy()




# Endpoint trả lời câu hỏi
@app.route('/ask', methods=['POST'])
async def ask():
    data = request.json
    user_input = data.get('question', '')
    
    if not user_input:
        return jsonify({"error": "Câu hỏi không được để trống."}), 400
    
    try:
        input_embedding = get_phobert_embedding(user_input).reshape(1, -1)
    except Exception as e:
        logger.error(f"Lỗi khi lấy embedding: {str(e)}")
        return jsonify({"error": "Không thể xử lý câu hỏi."}), 500
    
    similarities = cosine_similarity(input_embedding, question_embeddings)
    max_similarity = float(similarities.max())

    logger.info(f"Độ tương đồng lớn nhất: {max_similarity}")
    most_similar_index = similarities.argmax()

    if max_similarity > 0.8:
        response = answers[most_similar_index]
    else:
        # Tìm kiếm bất đồng bộ với Google Custom Search API
        search_results = await google_search(user_input, api_key, cse_id)
        response = generate_response_from_google_results(search_results)

    return jsonify({
        "question": user_input,
        "response": response,
        "similarity": max_similarity
    })
# Khởi chạy Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
