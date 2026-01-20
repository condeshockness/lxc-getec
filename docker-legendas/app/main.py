from fastapi import FastAPI
from pydantic import BaseModel
import yt_dlp
import whisper
import uuid
import os

DATA_DIR = "/data"
os.makedirs(DATA_DIR, exist_ok=True)

model = whisper.load_model("base")  # tiny | base | small

app = FastAPI()

class Req(BaseModel):
    url: str

@app.post("/transcribe")
def transcribe(req: Req):
    vid = str(uuid.uuid4())
    audio_file = f"/tmp/{vid}.mp3"

    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": audio_file,
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
        }],
        "quiet": True,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([req.url])

    result = model.transcribe(audio_file)

    md_file = f"{DATA_DIR}/{vid}.md"

    with open(md_file, "w", encoding="utf-8") as f:
        f.write("# Transcrição de Vídeo do YouTube\n\n")
        f.write(f"**URL:** {req.url}\n\n")
        f.write("---\n\n")
        f.write("## Texto\n\n")
        f.write(result["text"].strip() + "\n")

    return {
        "status": "ok",
        "file": md_file,
        "preview": result["text"][:500]
    }
