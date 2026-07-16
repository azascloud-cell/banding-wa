/**
 * jwt.ts — JWT sign & verify helpers
 */

import jwt from "jsonwebtoken";

const SECRET = process.env.SESSION_SECRET ?? "change-me-in-production";
const EXPIRES_IN = "30d";

export interface JwtPayload {
  userId: number;
  username: string;
}

export function signToken(payload: JwtPayload): string {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN });
}

export function verifyToken(token: string): JwtPayload {
  return jwt.verify(token, SECRET) as JwtPayload;
}
