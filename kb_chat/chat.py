import streamlit as st
import pickle
from langchain.vectorstores import FAISS
from dotenv import load_dotenv
import openai
import os

load_dotenv()

openai.api_key = os.getenv("OPENAI_API_KEY")

def gen_prompts(content, question):
    system_msg_content = "You are a questioning answering expert about MariaDB. You only respond based on the facts that are given to you and ignore your prior knowledge."
    user_msg_content = f"{content}\n---\n\nGiven the above content about MariaDB along with the URL of the content, respond to this question {question} and mention the URL as a source. If the question is not about MariaDB and you cannot answer it based on the provided content, politely decline to answer. Simply state that you couldn't find any relevant information instead of going into details. Do not say the phrase 'in the provided content'. If the information I provide contains the word obsolete, emphasize that the response is obsolete. Also, suggest newer MariaDB versions if the question is about versions older than 10.3 and say that the others are no longer maintained. Do not add the URL as a source if you cannot answer based on the provided content. If there are exceptions for particular MariaDB version, specify the exceptions that apply. Also, if the provided score is lower than 0.2 decline to answer and say you found no relevant information. If the source URL repeats, only use it once."
    system_msg = {"role": "system", "content": system_msg_content}
    user_msg = {"role": "user", "content": user_msg_content}

    return system_msg, user_msg

def process_doc(content, question, model_type="gpt-4", max_tokens=30000):
    if len(content) > max_tokens:
        print('Trimmed')
        content = content[:max_tokens]
    system_msg, user_msg = gen_prompts(content, question)

    try:
        response = openai.ChatCompletion.create(
            model=model_type,
            messages=[system_msg, user_msg],
        )
    except Exception as e:
        return "Sorry, there was an error. Please try again!"

    result = response.choices[0].message['content']
    return result

with open("vectorstore.pkl", "rb") as f:
    faiss_index = pickle.load(f)

def search_similar_docs(question, k=4):
    docs = faiss_index.similarity_search_with_score(question, k=k)
    docs_with_url = []
    for doc in docs:
        url = doc[0].metadata["source"]
        doc[0].page_content = f"URL: {url}\n{doc[0].page_content}\nSCORE:{doc[1]}\n"
        docs_with_url.append(doc[0])
    print(docs)
    return docs_with_url

def main():
    st.title("MariaDB KB Chatbot")

    if 'chat_history' not in st.session_state:
        st.session_state.chat_history = []

    user_input = st.text_input("Ask a question:", "")
    if st.button("Send"):
        st.session_state.chat_history.append(("User", user_input))
        results = process_doc(search_similar_docs(user_input), user_input)

        st.session_state.chat_history.append(("Bot", results))

    for role, message in st.session_state.chat_history:
        if role == "User":
            st.markdown(f"> **{role}**: {message}")
        else:
            st.markdown(f"**{role}**: {message}")

if __name__ == "__main__":
    main()
