import type { APIGatewayProxyResult } from "aws-lambda";
import { Env } from "./env";

type TriggerAction = "plan" | "apply" | "destroy"
type TriggerEvent = {
  action: TriggerAction
}

export async function handler({ action }: TriggerEvent): Promise<APIGatewayProxyResult> {
  console.log("Starting Lambda Infra Scheduler Trigger");

  await triggerSchedule(action)

  console.log("Lambda Infra Scheduler Trigger completed")

  return {
    statusCode: 204,
    body: `Finished triggering workflow schedule at "${Env.GitHub.Workflow.Id}"`
  }
}

async function triggerSchedule(action: TriggerAction) {
  try {
    console.debug(`Preparing to trigger GitHub API Request for workflow "${Env.GitHub.Workflow.Id}"...`)
    const response = await fetch(`https://api.github.com/repos/nori-cloud/infra/actions/workflows/${Env.GitHub.Workflow.Id}/dispatches`, {
      method: "POST",
      headers: {
        "Accept": "application/vnd.github+json",
        "Authorization": `Bearer ${Env.GitHub.Token}`,
        "X-GitHub-Api-Version": "2022-11-28"
      },
      body: JSON.stringify({
        ref: Env.GitHub.Workflow.Ref,
        inputs: {
          action
        }
      })
    })

    if (!response.ok) {
      await notifyTrigger(`Uh oh, something went wrong when triggering "${Env.GitHub.Workflow.Id}" with "${action}" action.`)
      throw new Error("GitHub API Request failed")
    }

    await notifyTrigger(`"${Env.GitHub.Workflow.Id}" is triggered with "${action}" action.`)
    console.debug(`Workflow "${Env.GitHub.Workflow.Id}" triggered successfully`)
  } catch (err) {

    if (err instanceof Error) {
      console.error("Error triggering workflow schedule", err.message)
    }

    console.error("Unknown Error", err)
  }

}

async function notifyTrigger(content: string) {
  try {
    console.debug(`Preparing to send notification via Discord Webhook "***********${Env.Discord.MessageWebhook.slice(-10)}"`)
    const response = await fetch(Env.Discord.MessageWebhook, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        content: `${content} meow 🐱`
      })
    })

    if (!response.ok) {
      console.error("Failed to send notification", await response.text())
      throw new Error("Failed to send notification via Discord Webhook.")
    }

    console.debug(`Notification sent to webhook "***********${Env.Discord.MessageWebhook.slice(-10)}"`)
  } catch (err) {
    if (err instanceof Error) {
      console.error("Error sending notification", err.message)
    }

    console.error("Unknown Error", err)
  }
}