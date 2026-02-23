import OpenAI from "openai";
import * as functions from "firebase-functions";

const client = new OpenAI({
  apiKey: functions.config().openai.key,
});

export const chatWithAI = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const userMessage = data.message;

    if (!userMessage) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Message is required"
      );
    }

    const completion =
      await client.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "You are a helpful assistant for a work-study program app.",
          },
          {
            role: "user",
            content: userMessage,
          },
        ],
      });

    return {
      reply: completion.choices[0].message.content,
    };
  }
);
