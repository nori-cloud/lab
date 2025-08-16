FROM public.ecr.aws/lambda/provided:al2.2025.08.15.14

WORKDIR /workspace

COPY ./aws .

COPY --from=ghcr.io/opentofu/opentofu:minimal /usr/local/bin/tofu /usr/local/bin/tofu

CMD ["tofu", "init"]
