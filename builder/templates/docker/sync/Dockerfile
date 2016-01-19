FROM frma/baseimage-unison

RUN groupadd --gid {{GID}} -r devuser \
 && useradd --uid {{UID}} --create-home --home /devuser --system --gid devuser devuser
