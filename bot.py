from PIL import Image
import telebot
import base64
from openai import OpenAI
from moviepy.config import change_settings
from moviepy.editor import (
    ImageClip,
    CompositeVideoClip,
    ColorClip,
    AudioFileClip,
    VideoFileClip,
    TextClip,
    concatenate_audioclips,
    concatenate_videoclips,
)
import os
import re
import threading
from dotenv import load_dotenv

# ==========================================
load_dotenv()

TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not TELEGRAM_TOKEN:
    raise RuntimeError("TELEGRAM_TOKEN 환경변수가 비어있습니다. .env 또는 환경변수를 확인하세요.")
if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY 환경변수가 비어있습니다. .env 또는 환경변수를 확인하세요.")

change_settings({"IMAGEMAGICK_BINARY": r"C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"})
# ==========================================

bot = telebot.TeleBot(TELEGRAM_TOKEN)
client = OpenAI(api_key=OPENAI_API_KEY, timeout=60)

W, H = 1080, 1920

# ====== 사용자 커스터마이즈 ======
FONT = "Malgun-Gothic-Bold"
INTRO_PATH = "intro.mp4"   # CapCut에서 만든 인트로 mp4
# ==============================


def encode_image(image_path: str) -> str:
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def _luminance_from_rgb(r, g, b) -> float:
    rr, gg, bb = r / 255.0, g / 255.0, b / 255.0
    return 0.2126 * rr + 0.7152 * gg + 0.0722 * bb


def pick_subtitle_style(image_path, margin=140, sample_height=360):
    """
    하단 자막 영역을 샘플링해서 배경이 어두우면 '흰 박스+검정 글자',
    밝으면 '검정 박스+흰 글자'로 자동 선택.
    (박스는 완전 불투명)
    """
    img = Image.open(image_path).convert("RGB")
    w0, h0 = img.size

    new_w = W
    new_h = int(h0 * (new_w / w0))
    img = img.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    top = (H - new_h) // 2
    canvas.paste(img, (0, top))

    y2 = H - margin
    y1 = max(0, y2 - sample_height)
    region = canvas.crop((0, y1, W, y2))

    pixels = list(region.getdata())
    r = sum(p[0] for p in pixels) / len(pixels)
    g = sum(p[1] for p in pixels) / len(pixels)
    b = sum(p[2] for p in pixels) / len(pixels)
    lum = _luminance_from_rgb(r, g, b)

    # ✅ 어두운 배경(검정에 가까움) => 흰 박스 + 검정 글자
    if lum < 0.45:
        return {
            "text_color": "#000000",
            "box_color": (255, 255, 255),
            "box_opacity": 1.0,
            "stroke_color": "#FFFFFF",
            "stroke_width": 3,
            "border_color": (255, 215, 0),  # 노란 테두리
            "border_thickness": 6,
        }

    # ✅ 밝은 배경 => 검정 박스 + 흰 글자
    return {
        "text_color": "#FFFFFF",
        "box_color": (0, 0, 0),
        "box_opacity": 1.0,
        "stroke_color": "#000000",
        "stroke_width": 6,
        "border_color": (255, 215, 0),  # 노란 테두리
        "border_thickness": 6,
    }


def generate_script_with_fallback(base64_image: str) -> str:
    prompts = [
        (
            "이 사진을 분석해서 유튜브 쇼츠용 내레이션 대본을 딱 5문장으로 써줘. "
            "각 문장은 짧게(대략 20~35자) 써줘. "
            "정치/시사 해설 또는 풍자 톤이되, 특정 인물/정당에 대한 지지·반대 유도, 선동, 투표 독려는 하지 마. "
            "사실 요약 3문장 + 해석 2문장. 이모지는 빼고 글자만."
        ),
        (
            "이 사진을 분석해서 유튜브 쇼츠용으로 5문장 요약을 써줘. "
            "각 문장은 짧게(대략 20~35자). "
            "중립적으로 상황만 설명하고 지지·반대 유도는 하지 마. 이모지는 빼고 글자만."
        ),
    ]

    last = ""
    for p in prompts:
        resp = client.chat.completions.create(
            model="gpt-4o",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": p},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}},
                ],
            }],
        )
        script = (resp.choices[0].message.content or "").strip()
        last = script
        if script and "요청을 처리할 수 없습니다" not in script:
            return script

    raise RuntimeError(f"대본 생성이 거절되었습니다. 마지막 응답: {last[:120]}")


def tts_to_file(text: str, out_path: str, voice="alloy", speed=1.05):
    """
    ✅ 핵심: 오디오는 문장 전체를 1번만 생성한다.
    (자막 줄바꿈 때문에 텍스트를 잘라서 TTS 돌리지 않음)
    """
    text_for_tts = (
        text.replace(",", ", ")
            .replace(".", ". ")
            .replace("!", "! ")
            .replace("?", "? ")
    )
    client.audio.speech.create(
        model="tts-1-hd",
        voice=voice,
        speed=speed,
        input=text_for_tts,
    ).write_to_file(out_path)


def wrap_two_lines_korean(text: str, max_chars_per_line: int = 18) -> str:
    """
    ✅ 단어 단위로만 2줄 줄바꿈. (어미/단어 중간 절대 자르지 않음)
    """
    s = re.sub(r"\s+", " ", text).strip()
    if len(s) <= max_chars_per_line:
        return s

    words = s.split(" ")
    line1, line2 = "", ""

    for w in words:
        if (len(line1) + (1 if line1 else 0) + len(w)) <= max_chars_per_line:
            line1 = f"{line1} {w}".strip()
        else:
            line2 = f"{line2} {w}".strip()

    if not line2:
        return s
    return f"{line1}\n{line2}"


def make_subtitle_clips(text: str, start: float, dur: float, margin: int, style: dict):
    """
    테두리(노란색) + 박스(불투명) + 텍스트
    """
    # 텍스트: 2줄(\n) 들어가면 그대로 2줄 표시됨
    txt_clip = TextClip(
        text,
        font=FONT,
        fontsize=68,
        color=style["text_color"],
        size=(980, None),
        method="caption",
        align="center",
        stroke_color=style["stroke_color"],
        stroke_width=style["stroke_width"],
    ).set_start(start).set_duration(dur)

    # 박스 패딩
    pad_x, pad_y = 70, 34
    box_w = int(txt_clip.w + pad_x)
    box_h = int(txt_clip.h + pad_y)

    x = (W - box_w) // 2
    y = H - box_h - margin

    bt = style["border_thickness"]

    border_clip = (
        ColorClip(size=(box_w + 2 * bt, box_h + 2 * bt), color=style["border_color"])
        .set_opacity(1.0)
        .set_start(start)
        .set_duration(dur)
        .set_position((x - bt, y - bt))
    )

    box_clip = (
        ColorClip(size=(box_w, box_h), color=style["box_color"])
        .set_opacity(style["box_opacity"])
        .set_start(start)
        .set_duration(dur)
        .set_position((x, y))
    )

    txt_clip = txt_clip.set_position(("center", y + (box_h - txt_clip.h) // 2))

    return [border_clip, box_clip, txt_clip]


def create_main_video(image_path, final_audio, text_clips, total_duration):
    clip = ImageClip(image_path).set_duration(total_duration).resize(width=W)
    zoom_clip = clip.resize(lambda t: 1 + 0.01 * t)
    bg = ColorClip(size=(W, H), color=(0, 0, 0)).set_duration(total_duration)

    main = CompositeVideoClip([bg, zoom_clip.set_position("center")] + text_clips).set_duration(total_duration)
    main = main.set_audio(final_audio)
    return main


def load_intro_clip(path: str):
    """
    intro mp4를 읽어서 1080x1920으로 맞춤.
    - 가로/세로 비율이 다르면 '중앙 크롭'으로 꽉 채움.
    """
    if not os.path.exists(path):
        raise RuntimeError(f"인트로 파일을 찾을 수 없습니다: {path}")

    intro = VideoFileClip(path)

    intro = intro.resize(height=H)
    if intro.w < W:
        intro = intro.resize(width=W)

    intro = intro.crop(
        x_center=intro.w / 2,
        y_center=intro.h / 2,
        width=W,
        height=H
    )
    return intro


def safe_remove(path: str):
    try:
        if os.path.exists(path):
            os.remove(path)
    except:
        pass


def process_photo(chat_id: int, file_id: str):
    temp_audio_paths = []
    clips_to_close = []

    try:
        bot.send_message(chat_id, "📥 사진 다운로드 중...")

        file_info = bot.get_file(file_id)
        downloaded_file = bot.download_file(file_info.file_path)
        photo_path = "input_photo.jpg"
        with open(photo_path, "wb") as f:
            f.write(downloaded_file)

        bot.send_message(chat_id, "🧠 사진 분석/대본 생성 중...")
        base64_image = encode_image(photo_path)
        script = generate_script_with_fallback(base64_image)

        bot.send_message(chat_id, f"📝 [완성된 대본]\n{script}")
        bot.send_message(chat_id, "🎙️ (1/3) 음성 생성 + 자막 싱크 준비 중...")

        sentences = re.split(r"(?<=[.!?])\s+|\n+", script.strip())
        sentences = [s for s in sentences if s.strip()]

        audio_clips = []
        text_clips = []
        current_time = 0.0

        # 하단 원본 UI(흰 바 등) 피하려고 살짝 올림
        margin = 140

        # ✅ 스타일은 1번만 계산(사진 기반)
        style = pick_subtitle_style(photo_path, margin=margin, sample_height=360)

        n = len(sentences)
        for i, sentence in enumerate(sentences, start=1):
            bot.send_message(chat_id, f"🔊 ({i}/{n}) 음성 생성 중...")

            # ✅ 오디오: 문장 전체를 1번만 생성 (절대 자르지 않음)
            temp_audio_path = f"speech_{i}.mp3"
            temp_audio_paths.append(temp_audio_path)
            tts_to_file(sentence, temp_audio_path, voice="alloy", speed=1.05)

            aud_clip = AudioFileClip(temp_audio_path)
            clips_to_close.append(aud_clip)
            audio_clips.append(aud_clip)

            bot.send_message(chat_id, f"📝 ({i}/{n}) 자막 생성 중...")

            # ✅ 자막만 2줄로 줄바꿈(단어 단위)
            subtitle_text = wrap_two_lines_korean(sentence, max_chars_per_line=18)

            text_clips.extend(
                make_subtitle_clips(subtitle_text, start=current_time, dur=aud_clip.duration, margin=margin, style=style)
            )

            current_time += aud_clip.duration

        final_audio = concatenate_audioclips(audio_clips)
        main_duration = final_audio.duration + 0.3

        bot.send_message(chat_id, "🎬 (2/3) 본편 합성 중...")
        main_video = create_main_video(photo_path, final_audio, text_clips, main_duration)

        bot.send_message(chat_id, "🎬 (3/3) 인트로 mp4 로드 + 렌더링 시작...")
        intro_clip = load_intro_clip(INTRO_PATH)
        clips_to_close.append(intro_clip)
        clips_to_close.append(main_video)

        final = concatenate_videoclips([intro_clip, main_video], method="compose")

        video_path = "final_shorts.mp4"
        final.write_videofile(video_path, fps=30, codec="libx264", audio_codec="aac", logger="bar")

        bot.send_message(chat_id, "✅ 렌더링 완료! 업로드 중...")
        with open(video_path, "rb") as video:
            bot.send_video(chat_id, video, caption="🎉 [완성] 인트로(mp4) + 본편 숏츠!", timeout=300)

    except Exception as e:
        bot.send_message(chat_id, f"❌ 에러 발생: {repr(e)}")

    finally:
        for c in clips_to_close:
            try:
                c.close()
            except:
                pass

        for p in temp_audio_paths:
            safe_remove(p)


@bot.message_handler(content_types=["photo"])
def handle_photo(message):
    bot.reply_to(message, "✅ 사진 접수 완료! (백그라운드 처리 시작)")
    t = threading.Thread(target=process_photo, args=(message.chat.id, message.photo[-1].file_id), daemon=True)
    t.start()


print("🚀 공장 가동 중.")
bot.infinity_polling(timeout=60, long_polling_timeout=60)