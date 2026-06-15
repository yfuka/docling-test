ARG DOCLING_BASE_IMAGE
FROM ${DOCLING_BASE_IMAGE}

ARG RAPIDOCR_MODELS_URL=https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.8.0
RUN models=/opt/app-root/src/.cache/docling/models/RapidOcr/custom && \
    mkdir -p "${models}/ppocrv5-server" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/torch/PP-OCRv5/det/ch_PP-OCRv5_det_server.pth" \
        -o "${models}/ppocrv5-server/ch_PP-OCRv5_det_server.pth" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/torch/PP-OCRv4/cls/ch_ptocr_mobile_v2.0_cls_mobile.pth" \
        -o "${models}/ppocrv5-server/ch_ptocr_mobile_v2.0_cls_mobile.pth" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/torch/PP-OCRv5/rec/ch_PP-OCRv5_rec_server.pth" \
        -o "${models}/ppocrv5-server/ch_PP-OCRv5_rec_server.pth" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/paddle/PP-OCRv5/rec/ch_PP-OCRv5_rec_server/ppocrv5_dict.txt" \
        -o "${models}/ppocrv5-server/keys.txt"
