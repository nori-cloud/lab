# testing cmds
# docker buildx build --platform linux/amd64 --provenance=false -t infra-scheduler:local .
# docker run --platform linux/amd64 -p 9000:8080 infra-scheduler:local
# curl "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'

FROM public.ecr.aws/lambda/python:3.12

COPY . ${LAMBDA_TASK_ROOT}

RUN pip install -r requirements.txt

CMD [ "scheduler.handler" ]
