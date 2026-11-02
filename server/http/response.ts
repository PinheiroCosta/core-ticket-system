export function jsonResponse<T>(data: T, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set("content-type", "application/json; charset=utf-8");

  return new Response(JSON.stringify(data), {
    ...init,
    headers,
  });
}

export function errorResponse(
  message: string,
  status: number,
  code: string,
): Response {
  return jsonResponse({ error: { code, message } }, { status });
}
