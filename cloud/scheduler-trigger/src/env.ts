// import z from "zod";

// const schema = z.object({
//   Discord: z.object({
//     MessageWebhook: z.url()
//   }),
//   GitHub: z.object({
//     Workflow: z.object({
//       Id: z.string(),
//       Ref: z.string()
//     }),
//     Token: z.string()
//   })
// })


// export const Env = schema.parse({
//   Discord: {
//     MessageWebhook: process.env.DISCORD_MESSAGE_WEBHOOK as string
//   },
//   GitHub: {
//     Workflow: {
//       Id: process.env.GITHUB_WORKFLOW_ID as string,
//       Ref: process.env.GITHUB_WORKFLOW_REF as string
//     },
//     Token: process.env.GITHUB_TOKEN as string
//   }
// } satisfies z.infer<typeof schema>)

export const Env = {
  Discord: {
    MessageWebhook: process.env.DISCORD_MESSAGE_WEBHOOK as string
  },
  GitHub: {
    Workflow: {
      Id: process.env.GITHUB_WORKFLOW_ID as string,
      Ref: process.env.GITHUB_WORKFLOW_REF as string
    },
    Token: process.env.GITHUB_TOKEN as string
  }
}
