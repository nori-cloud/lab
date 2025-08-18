import type { APIGatewayProxyResult } from "aws-lambda";
import { Env } from "./env";

type TriggerAction = "plan" | "apply" | "destroy"
type TriggerEvent = {
  ref: string;
  inputs: {
    action: TriggerAction
  }
}

export async function handler(event: TriggerEvent): Promise<APIGatewayProxyResult> {
  console.log("Starting Lambda Infra Scheduler Trigger");

  const { action } = event.inputs

  await notifyTrigger(`Lambda Infra Scheduler is triggered with "${action}" action.`)
  await triggerSchedule(action)

  console.log("Lambda Infra Scheduler Trigger completed")

  return {
    statusCode: 204,
    body: `Finished triggering workflow schedule at "${Env.GitHub.Workflow.Id}"`
  }
}

async function triggerSchedule(action: TriggerAction) {
  try {
    const response = await fetch(`https://api.github.com/repos/nori-cloud/infra/actions/workflows/${Env.GitHub.Workflow.Id}/dispatches`, {
      method: "POST",
      headers: {
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer <YOUR-TOKEN>",
        "X-GitHub-Api-Version": "2022-11-28"
      },
      body: JSON.stringify({
        ref: "main",
        inputs: {
          action
        }
      })
    })

    if (!response.ok) {
      console.debug(response)
      throw new Error("GitHub API Request failed")
    }
  } catch (err) {

    if (err instanceof Error) {
      console.error("Error triggering workflow schedule", err.message)
    }

    console.error("Unknown Error", err)
  }

}

async function notifyTrigger(content: string) {
  try {
    const response = await fetch(Env.Discord.MessageWebhook, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        content
      })
    })

    if (!response.ok) {
      throw new Error("Failed to send notification via Discord Webhook.")
    }

  } catch (err) {


  }
}