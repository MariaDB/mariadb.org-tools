import argparse
import pickle
import os
import csv
import openai
import re
import requests

from langchain.document_loaders import BSHTMLLoader
from langchain.vectorstores import FAISS
from langchain.text_splitter import CharacterTextSplitter
from langchain.embeddings.openai import OpenAIEmbeddings
from dotenv import load_dotenv

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")

def parse_args():
    parser = argparse.ArgumentParser(description='MariaDB KB Vector Store Generator')
    parser.add_argument('--csv-file', type=str, default='kb_urls.csv', help='Path to the input CSV file containing the URLs')
    parser.add_argument('--tmp-dir', type=str, default='tmp', help='Directory where the temporary HTML files will be stored')
    parser.add_argument('--vectorstore-path', type=str, default='vectorstore.pkl', help='Path to save the generated FAISS vector store pickle file')
    parser.add_argument('--chunk-size', type=int, default=4000, help='Chunk size for splitting the documents')
    parser.add_argument('--chunk-overlap', type=int, default=200, help='Overlap size between chunks when splitting documents')
    return parser.parse_args()

def download_web_page(url):
    response = requests.get(url)

    if response.status_code == 200:
        content = response.text
        filename = url.replace('://', '_').replace('/', '_') + '.html'

        with open('./tmp/' + filename, 'w', encoding='utf-8') as file:
            file.write(content)
    else:
        print(f"Error: Unable to fetch the web page. Status code: {response.status_code}")

def read_csv(csv_file):
    urls = []

    with open(csv_file, newline='', encoding='utf-8') as csvfile:
        csv_reader = csv.reader(csvfile)
        for row in csv_reader:
            if row[0].strip():
                urls.append(row[0])

    return urls[1:]

def main():
    args = parse_args()

    urls = read_csv(args.csv_file)
    all_docs = []
    idx = 0
    for url in urls:
        filename = url.replace('://', '_').replace('/', '_').strip() + '.html'
        doc_path = args.tmp_dir + '/' + filename
        if not os.path.exists(doc_path):
            download_web_page(url)
        loader = BSHTMLLoader(doc_path)
        doc = loader.load()[0]

        content = re.sub(r'\s+', ' ', doc.page_content)
        doc.page_content = content
        doc.metadata["source"] = url

        all_docs.append(doc)

    text_splitter = CharacterTextSplitter(
        separator = " ",
        chunk_size = args.chunk_size,
        chunk_overlap  = args.chunk_overlap,
        length_function = len,
    )
    print("Loaded {} documents".format(len(all_docs)))
    all_docs = text_splitter.split_documents(all_docs)
    print("After split: {} documents".format(len(all_docs)))

    faiss_index = FAISS.from_documents(all_docs, OpenAIEmbeddings())

    with open(args.vectorstore_path, "wb") as f:
        pickle.dump(faiss_index, f)

if __name__ == "__main__":
    main()
