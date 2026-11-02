import { jsonResponse } from "../../../server/http/response";

export const onRequestGet: PagesFunction<Env> = () =>
  jsonResponse({ status: "ok" });
