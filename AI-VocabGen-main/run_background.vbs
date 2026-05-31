Set objShell = CreateObject("WScript.Shell")

' المسارات
strBaseDir = "c:\Users\HP 250 G9\OneDrive\سطح المكتب\AI_VOCABGEN_CLEAN_SM2\AI-VocabGen-main"
strBackendDir = strBaseDir & "\Back-End"

' تشغيل Backend في الخلفية
Set objFSO = CreateObject("Scripting.FileSystemObject")

' تحضير Backend
objShell.CurrentDirectory = strBackendDir

' إنشاء ملف .env إذا لم يكن موجوداً
If Not objFSO.FileExists(strBackendDir & "\.env") Then
    objFSO.CopyFile strBackendDir & "\.env.example", strBackendDir & "\.env"
End If

' تثبيت المتعلقات
objShell.Run "cmd /c cd /d """ & strBackendDir & """ && pip install -r requirements.txt", 0, true

' تشغيل Backend في الخلفية
objShell.Run "cmd /c cd /d """ & strBackendDir & """ && python run_backend.py", 0, false

' رسالة توضيحية
MsgBox "✅ تم بدء Backend في الخلفية!" & vbCrLf & vbCrLf & _
        "📍 Backend: http://127.0.0.1:8000" & vbCrLf & _
        "📍 API Docs: http://127.0.0.1:8000/docs" & vbCrLf & vbCrLf & _
        "💡 لإيقاف Backend، اذهب إلى Task Manager وابحث عن 'python.exe'", _
        0, "AI-VocabGen Backend جاري التشغيل"
