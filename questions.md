# Sample questions for the RAG demo (Streamlit on :8501)

Questions grounded in the three PDFs under `rag/src/rag/data/`:

- `jd_1.pdf` — Senior Platform Engineer job description (Greenbox Capital)
- `Governors_Small_Business_Handbook.pdf` — Texas Governor's Small Business Handbook
- `mi-sbdc-english-fullbook.pdf` — Michigan SBDC Guide to Starting and Operating a Small Business

The UI returns both an **Answer** and a **Source** filepath, so the comparison questions at the bottom double as retrieval sanity checks.

---

## 1. `jd_1.pdf` — Senior Platform Engineer (Greenbox Capital)

- What role is described in the job description and who does it report to?
- How many years of Python experience does the Senior Platform Engineer role require?
- Which cloud platform does Greenbox Capital prefer?
- What are the steps in Greenbox Capital's interview process?
- What benefits does Greenbox Capital offer?
- Is the Senior Platform Engineer position remote, and what time zone is required?
- What "nice-to-have" skills are listed for the platform engineer role?
- What does Greenbox Capital do, and how does this role support that mission?
- What are the core values mentioned at Greenbox Capital?

## 2. `Governors_Small_Business_Handbook.pdf` — Texas

- What are the 7 steps to start a business in Texas?
- How do I register a business name in Texas (DBA / assumed name)?
- Which state agency handles state tax filings in Texas?
- What financing options are available for a new small business in Texas?
- What is HUB certification and who is it for?
- Where can veterans find small business resources in Texas?
- What federal programs are available for small business financing?
- What resources does the SBA offer for Texas small businesses?

## 3. `mi-sbdc-english-fullbook.pdf` — Michigan SBDC

- What are the 10 steps to starting a small business according to the Michigan SBDC?
- What sections should a Michigan SBDC business plan include?
- What is the difference between an employee and a contractor?
- What does the Michigan SBDC recommend for cybersecurity / ransomware?
- What are the Four Ps of Marketing?
- How do I become a State of Michigan contractor?
- What is a PTAC and how can it help with government bidding?
- Why should I create separate bank accounts for my business?

---

## Cross-document / retrieval sanity checks

- Compare Texas vs. Michigan resources for starting a small business.
- What does each handbook say about choosing a legal business structure?
- Which document mentions FastAPI? *(should return `jd_1.pdf`)*
- Which document talks about the Four Ps of Marketing? *(should return `mi-sbdc-english-fullbook.pdf`)*
- Which document mentions HUB certification? *(should return `Governors_Small_Business_Handbook.pdf`)*
