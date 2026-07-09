# Project Setup and Run Guide

## Requirements
1.  Python 3.10+ installed.
2.  Install dependencies:
    ```bash
    pip install flask psutil pyinstaller google-generativeai
    ```
    *(Note: Add any other libraries from imports like keyauth, etc if they are pip installable)*

## How to Build EXE (Executable)
To create a single `.exe` file that contains everything (HTML, DLLs, etc.):

1.  Double-click **`build.bat`**.
2.  Wait for the process to finish.
3.  Go to the **`dist`** folder.
4.  You will find **`app.exe`**. This is the only file you need to share.

## How it Works
- The `app.exe` contains the Python interpreter, your code, HTML files, and DLLs.
- When you run `app.exe`, it extracts the necessary files to a temporary folder and runs the Flask server.
- The "Host" (Server) will be active as long as the application is running.

## Note for Distribution
- Just copy `dist/app.exe` and give it to the other person.
- They **do not** need Python installed.

## Troubleshooting
- **Missing DLL Error**: If it says a DLL is missing, make sure all DLL files are in the same folder as `app.exe` (though they should be packed inside).
- **Antivirus Deletes EXE**: Add an exclusion for the folder in Windows Defender.
- **Failed to Execute Script**: This usually means a dependency is missing. Contact the developer.
