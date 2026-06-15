ARG DOCLING_BASE_IMAGE
FROM ${DOCLING_BASE_IMAGE}

USER 0
RUN dnf install -y --best --nodocs --setopt=install_weak_deps=False \
        curl \
        tesseract-langpack-jpn && \
    dnf -y clean all && \
    rm -rf /var/cache/dnf

ARG RAPIDOCR_MODELS_URL=https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.8.0
RUN models=/opt/app-root/src/.cache/docling/models/RapidOcr/custom && \
    mkdir -p "${models}/ppocrv5-server" "${models}/ppocrv5-mobile" "${models}/ppocrv4-japan" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/onnx/PP-OCRv5/det/ch_PP-OCRv5_det_server.onnx" \
        -o "${models}/ppocrv5-server/det.onnx" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/onnx/PP-OCRv5/cls/ch_PP-LCNet_x1_0_textline_ori_cls_server.onnx" \
        -o "${models}/ppocrv5-server/cls.onnx" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/onnx/PP-OCRv5/rec/ch_PP-OCRv5_rec_server.onnx" \
        -o "${models}/ppocrv5-server/rec.onnx" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/paddle/PP-OCRv5/rec/ch_PP-OCRv5_rec_server/ppocrv5_dict.txt" \
        -o "${models}/ppocrv5-server/keys.txt" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/onnx/PP-OCRv5/det/ch_PP-OCRv5_det_mobile.onnx" \
        -o "${models}/ppocrv5-mobile/det.onnx" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/onnx/PP-OCRv5/cls/ch_PP-LCNet_x0_25_textline_ori_cls_mobile.onnx" \
        -o "${models}/ppocrv5-mobile/cls.onnx" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/onnx/PP-OCRv5/rec/ch_PP-OCRv5_rec_mobile.onnx" \
        -o "${models}/ppocrv5-mobile/rec.onnx" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/paddle/PP-OCRv5/rec/ch_PP-OCRv5_rec_mobile/ppocrv5_dict.txt" \
        -o "${models}/ppocrv5-mobile/keys.txt" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/onnx/PP-OCRv4/rec/japan_PP-OCRv4_rec_mobile.onnx" \
        -o "${models}/ppocrv4-japan/rec.onnx" && \
    curl -fL "${RAPIDOCR_MODELS_URL}/paddle/PP-OCRv4/rec/japan_PP-OCRv4_rec_mobile/japan_dict.txt" \
        -o "${models}/ppocrv4-japan/keys.txt" && \
    chown -R 1001:0 "${models}" && \
    chmod -R g=u "${models}"

USER 1001
