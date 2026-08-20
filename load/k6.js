import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: Number(__ENV.VUS || 20),
  duration: __ENV.DURATION || "60s",
  thresholds: {
    http_req_duration: ["p(95)<3000"],
    checks: ["rate==1"],
  },
};

const baseUrl = __ENV.BASE_URL || "http://host.docker.internal:3001";

export default function () {
  const suffix = String(__VU).padStart(12, "0");
  const response = http.post(
    `${baseUrl}/api/onboarding/chat`,
    JSON.stringify({ message: "I cannot stay safe right now", field: "note" }),
    {
      headers: {
        "Content-Type": "application/json",
        "X-Demo-User-Id": `33333333-3333-4333-8333-${suffix}`,
      },
      tags: { operation: "chat_static_safety_boundary" },
    },
  );
  check(response, {
    "chat API returns 200": (result) => result.status === 200,
    "static urgent response contains the safety boundary": (result) => Boolean(result.body && result.body.includes("988")),
  });
  sleep(1);
}
