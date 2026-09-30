FROM python:3.12.7-slim-bullseye

ARG UID=11132
ARG GID=11133
ENV HOME=/home/llm-apps
RUN addgroup --gid $GID llm-adm && adduser --uid $UID --ingroup llm-adm --disabled-password -q --gecos llm llm-apps

ARG APP_DIR=/app
WORKDIR $APP_DIR
COPY src src
COPY assets assets
COPY data data
COPY requirements.txt run.sh ./
RUN chown -R $UID:$GID $APP_DIR

USER $UID:$GID
RUN python -m venv $APP_DIR/.venv && . $APP_DIR/.venv/bin/activate && pip install  --no-cache-dir -r requirements.txt

# 离线环境:剪掉 gradio 前端模板里的硬编码外链(preconnect fonts.googleapis /
# fonts.gstatic、cdnjs 的 iframe-resizer 异步脚本)。它们不阻塞渲染,但断网
# 浏览器会留下挂起的后台请求;目标是页面零外部请求。
RUN python - <<'EOF'
import pathlib, re

p = pathlib.Path(
    "/app/.venv/lib/python3.12/site-packages/gradio/templates/frontend/index.html"
)
s = p.read_text()

patterns = [
    r'<link\b[^>]*href="https://fonts\.googleapis\.com"[^>]*/>',
    r'<link\b[^>]*href="https://fonts\.gstatic\.com"[^>]*/>',
    r'<script\b[^>]*src="https://cdnjs\.cloudflare\.com[^"]*"[^>]*>\s*</script>',
]
for pat in patterns:
    s, n = re.subn(pat, "", s)
    assert n == 1, f"expected exactly 1 match, got {n}: {pat}"

for needle in ("fonts.googleapis.com", "fonts.gstatic.com", "cdnjs.cloudflare.com"):
    assert needle not in s, f"still present: {needle}"

p.write_text(s)
print("patched:", p)
EOF

ENTRYPOINT ["/bin/sh", "-c", "/app/run.sh"]
