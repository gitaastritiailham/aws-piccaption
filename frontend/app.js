// ==============================================
// PicCaption Phase 1 — app.js
// S3 + Lambda + DynamoDB + API Gateway
// Tanpa login / Cognito
// ==============================================

// CONFIG — diisi otomatis oleh deploy.sh
const CONFIG = {
  API_URL: "%%API_URL%%",  // https://xxxx.execute-api.us-east-1.amazonaws.com/prod
};

// -----------------------------------------------
// FILE HANDLING
// -----------------------------------------------
let selectedFile = null;

function onFileSelect(e) {
  const file = e.target.files[0];
  if (file) setPreview(file);
}

function onDragOver(e) {
  e.preventDefault();
  document.getElementById("drop-zone").classList.add("dragover");
}

function onDragLeave() {
  document.getElementById("drop-zone").classList.remove("dragover");
}

function onDrop(e) {
  e.preventDefault();
  document.getElementById("drop-zone").classList.remove("dragover");
  const file = e.dataTransfer.files[0];
  if (file && file.type.startsWith("image/")) setPreview(file);
}

function setPreview(file) {
  selectedFile = file;

  const reader = new FileReader();
  reader.onload = e => {
    document.getElementById("preview-img").src = e.target.result;
  };
  reader.readAsDataURL(file);

  document.getElementById("preview-name").textContent = file.name;
  document.getElementById("preview-size").textContent =
    (file.size / 1024).toFixed(1) + " KB";
  document.getElementById("caption-input").value = "";
  document.getElementById("preview-wrap").style.display = "flex";
}

// -----------------------------------------------
// UPLOAD
// -----------------------------------------------
async function uploadImage() {
  if (!selectedFile) return;

  const caption  = document.getElementById("caption-input").value.trim();
  const progress = document.getElementById("upload-progress");
  const fill     = document.getElementById("progress-fill");
  const label    = document.getElementById("progress-label");

  progress.style.display = "block";
  fill.style.width = "10%";
  label.textContent = "URLを取得中...";

  try {
    // Step 1: Minta presigned URL ke API Gateway → Lambda
    const res = await fetch(CONFIG.API_URL + "/upload", {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        fileName: selectedFile.name,
        fileType: selectedFile.type,
        caption:  caption,
      }),
    });

    if (!res.ok) throw new Error("API error: " + res.status);
    const { uploadUrl } = await res.json();

    fill.style.width  = "40%";
    label.textContent = "S3にアップロード中...";

    // Step 2: Upload langsung ke S3 via presigned URL
    const uploadRes = await fetch(uploadUrl, {
      method:  "PUT",
      headers: { "Content-Type": selectedFile.type },
      body:    selectedFile,
    });

    if (!uploadRes.ok) throw new Error("S3 upload error: " + uploadRes.status);

    fill.style.width  = "100%";
    label.textContent = "✅ アップロード完了！";

    // Reset setelah 1.5 detik lalu reload gallery
    setTimeout(() => {
      progress.style.display = "none";
      document.getElementById("preview-wrap").style.display = "none";
      selectedFile = null;
      document.getElementById("file-input").value = "";
      fill.style.width = "0%";
      loadImages();
    }, 1500);

  } catch (e) {
    console.error(e);
    label.textContent = "❌ エラー: " + e.message;
  }
}

// -----------------------------------------------
// GALLERY
// -----------------------------------------------
async function loadImages() {
  const btn = document.getElementById("refresh-btn");
  btn.classList.add("spinning");

  try {
    const res = await fetch(CONFIG.API_URL + "/images");
    if (!res.ok) throw new Error("API error: " + res.status);
    const { images } = await res.json();
    renderGallery(images);
  } catch (e) {
    console.error("画像の読み込みに失敗:", e);
    document.getElementById("gallery-grid").innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">⚠️</div>
        <p>画像の読み込みに失敗しました<br>${e.message}</p>
      </div>`;
  } finally {
    btn.classList.remove("spinning");
  }
}

function renderGallery(images) {
  const grid = document.getElementById("gallery-grid");

  if (!images || images.length === 0) {
    grid.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">📷</div>
        <p>まだ画像がありません<br>最初の写真をアップロードしましょう</p>
      </div>`;
    return;
  }

  grid.innerHTML = images.map(img => {
    const date = new Date(img.createdAt).toLocaleDateString("ja-JP", {
      year: "numeric", month: "numeric", day: "numeric",
    });

    const captionHtml = img.caption
      ? `<div class="caption-text">${img.caption}</div>`
      : `<div class="caption-text empty">キャプションなし</div>`;

    return `
      <div class="img-card">
        <img src="${img.viewUrl}" alt="${img.fileName}" loading="lazy" />
        <div class="img-body">
          <div class="caption-label">✨ Caption</div>
          ${captionHtml}
          <div class="img-meta">
            <span class="status-dot"></span>
            ${img.fileName} · ${date}
          </div>
        </div>
      </div>`;
  }).join("");
}

// -----------------------------------------------
// INIT
// -----------------------------------------------
window.onload = () => {
  loadImages();
};
