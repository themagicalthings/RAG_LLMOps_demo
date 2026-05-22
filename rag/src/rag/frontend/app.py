import streamlit as st
import httpx
import os

API_URL = os.getenv("API_URL", "http://localhost:8000")


def layout():
    st.markdown("# RAG_LLMOps_Demo")
    st.markdown("Ask a question about the documents")

    text_input = st.text_input(label="ask a question")

    if st.button("send") and text_input.strip() != "":
        response = httpx.post(f"{API_URL}/rag/query", json={"prompt": text_input}, timeout=120)
        data = response.json()

        st.markdown("## Question:")
        st.markdown(text_input)

        st.markdown("## Answer:")
        st.markdown(data["answer"])

        st.markdown("## Source:")
        st.markdown(data["filepath"])


if __name__ == "__main__":
    layout()