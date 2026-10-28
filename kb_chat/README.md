# MariaDB KB Chat and Vector Store Generator

This script scrapes web pages from the MariaDB Knowledge Base, cleans and processes the content, and then generates a FAISS index using the OpenAI embeddings for each document. The vector store is saved as a pickle file and then used by a chatbot to answer questions about the MariaDB server.

## Requirements

Install the required packages with the following command:

pip install argparse bs4 dotenv faiss-cpu openai requests numpy streamlit

## Setup

1. Download the MariaDB KB CSV file from https://github.com/Icerath/mariadb_kb_server/blob/main/kb_urls.csv
2. Create a `.env` file in the same directory as the script.
3. Add your OpenAI API key to the `.env` file as follows:

OPENAI_API_KEY=your_api_key_here

## Preprocessing

Run the script with the following command:

python create_vectorestore.py --csv-file kb_urls.csv --tmp-dir tmp --vectorstore-path vectorstore.pkl --chunk-size 4000 --chunk-overlap 200

This will create a file `vectorestore.pkl` which is used to answer questions

## Run chat

streamlit run chat.py

Now, you will have a self hosted version of the chat over the MariaDB KB.
