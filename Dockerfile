# syntax=docker/dockerfile:1
# =============================================================================
# Overleaf CE — Japanese LaTeX Custom Image
# Base : sharelatex/sharelatex:6
#
# 最優先目標: LuaLaTeX / XeLaTeX における高速・安定した日本語組版
# =============================================================================

FROM sharelatex/sharelatex:6

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    TEXMFVAR=/var/lib/overleaf/tmp/texmf-var

# ---------------------------------------------------------------------------
# 層A: 基本システム依存＋日本語フォント（滅多に変わらない）
# ---------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        fontconfig \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        fonts-ipafont \
        fonts-ipaexfont \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 層B: tlmgr バイナリのアップグレード（滅多に変わらない）
# ---------------------------------------------------------------------------
RUN wget --no-verbose \
        https://mirror.ctan.org/systems/texlive/tlnet/update-tlmgr-latest.sh \
        -O /tmp/update-tlmgr-latest.sh \
    && sh /tmp/update-tlmgr-latest.sh -- --upgrade \
    && rm /tmp/update-tlmgr-latest.sh

# ---------------------------------------------------------------------------
# 層C: TeXLive 全パッケージをアップデート（滅多に変わらない）
# ---------------------------------------------------------------------------
RUN tlmgr update --self --all

# ---------------------------------------------------------------------------
# 層D: 必須日本語 TeX パッケージ（滅多に変わらない）
#
#   [LuaLaTeX]  luatexja, lltjext, luatexja-fontspec 等
#   [XeLaTeX]   xecjk, zxjatype
#   [共通]      bxjscls, jlreq, bxbase, bxcjkjatype
#   [フォント]  ipaex, haranoaji, haranoaji-extra, noto
#   [その他]    collection-langcjk, latexmk
# ---------------------------------------------------------------------------
RUN tlmgr install \
        luatexja \
        jsclasses \
        xecjk \
        zxjatype \
        bxjscls \
        jlreq \
        bxbase \
        bxcjkjatype \
        ipaex \
        haranoaji \
        haranoaji-extra \
        noto \
        collection-langcjk \
        latexmk \
        luacode \
        amsmath \
        filehook

# ---------------------------------------------------------------------------
# 層E: オプショナル追加パッケージ（ここだけ頻繁に変更する）
#
#   数学・科学:  siunitx, diffcoeff, physics2, mleftright, upgreek
#   図表・装飾:  tcolorbox, booktabs, float, titlepic, fontawesome5
#   その他:      listings, xurl, cleveref, hyperref
#   コレクション: collection-latexextra, collection-mathscience,
#                collection-pictures, collection-fontsextra, was
# ---------------------------------------------------------------------------
RUN tlmgr install \
        siunitx \
        diffcoeff \
        physics2 \
        mleftright \
        upgreek \
        tcolorbox \
        booktabs \
        float \
        titlepic \
        fontawesome5 \
        listings \
        xurl \
        cleveref \
        hyperref \
        pgf \
        graphics \
        xcolor \
        collection-latexextra \
        collection-mathscience \
        collection-pictures \
        collection-fontsextra \
        was

# ---------------------------------------------------------------------------
# 層F: kpathsea ls-R データベース生成＋fmt 事前コンパイル
#
#   - mktexlsr: パッケージ検索パスをインデックス化しディスク走査を排除
#   - fmtutil-sys: 必要なエンジンのみ選択生成（--all は無駄が大きい）
# ---------------------------------------------------------------------------
RUN mktexlsr \
    && fmtutil-sys --byfmt lualatex \
    && fmtutil-sys --byfmt luahblatex \
    && fmtutil-sys --byfmt xelatex \
    || (echo "[WARN] Some fmtutil-sys steps failed, continuing..." && true)

# ---------------------------------------------------------------------------
# 層G: フォントキャッシュ構築（ランタイム初回起動のタイムアウト対策）
#
#   - fc-cache:        XeLaTeX / fontconfig 用システムフォントキャッシュ
#   - luaotfload-tool: LuaLaTeX 用 OpenType フォントキャッシュ
#                      --prefer-texmf でシステムフォント走査を抑制し高速化
# ---------------------------------------------------------------------------
RUN fc-cache -fv \
    && luaotfload-tool --update --force --prefer-texmf \
    || echo "[WARN] Font cache generation had issues, will regenerate on first run"

# ---------------------------------------------------------------------------
# 最終クリーンアップ
# ---------------------------------------------------------------------------
RUN rm -rf /tmp/*
