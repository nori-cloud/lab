FROM public.ecr.aws/lambda/nodejs:22 AS builder
WORKDIR /usr/app

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

COPY package.json .
COPY pnpm-lock.yaml .
COPY src ./src
COPY tsup.config.ts ./tsup.config.ts

RUN pnpm install --frozen-lockfile
RUN pnpm run build
    
FROM public.ecr.aws/lambda/nodejs:22
WORKDIR ${LAMBDA_TASK_ROOT}

COPY --from=builder /usr/app/dist/* ./
CMD ["index.handler"]