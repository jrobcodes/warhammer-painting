import { DynamoDBClient, GetItemCommand, PutItemCommand } from "@aws-sdk/client-dynamodb";

const db = new DynamoDBClient({});
const TABLE = process.env.TABLE_NAME || "painting-progress";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Content-Type": "application/json",
};

export const handler = async (event) => {
  const method = event.requestContext?.http?.method || event.httpMethod;
  const userId = event.pathParameters?.userId
    || event.rawPath?.split("/").filter(Boolean)[0]
    || "default";

  // CORS preflight
  if (method === "OPTIONS") {
    return { statusCode: 204, headers };
  }

  // GET — read progress
  if (method === "GET") {
    const result = await db.send(new GetItemCommand({
      TableName: TABLE,
      Key: { userId: { S: userId } },
    }));
    const data = result.Item?.data?.S || "{}";
    return { statusCode: 200, headers, body: data };
  }

  // PUT — write progress
  if (method === "PUT") {
    const body = event.body || "{}";
    await db.send(new PutItemCommand({
      TableName: TABLE,
      Item: {
        userId: { S: userId },
        data: { S: body },
        updatedAt: { S: new Date().toISOString() },
      },
    }));
    return { statusCode: 200, headers, body: JSON.stringify({ ok: true }) };
  }

  return { statusCode: 405, headers, body: JSON.stringify({ error: "Method not allowed" }) };
};
