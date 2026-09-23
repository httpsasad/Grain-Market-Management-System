import uvicorn

if __name__ == "__main__":
    print("=========================================================")
    print("Grain Market Management System (AI Mandi ERP)")
    print("Starting server on http://127.0.0.1:8000 ...")
    print("=========================================================")
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)

