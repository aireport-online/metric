"use server";

import { refresh } from "next/cache";
import { z } from "zod";
import { friendRequestSchema } from "@/lib/schemas";
import { formError, type FormState } from "@/server/form";
import { acceptFriendRequest, deleteFriendRequest, removeFriend, sendFriendRequest } from "@/server/friends";
import { requireUser } from "@/server/session";

export async function sendFriendRequestAction(username: string, _prev: FormState): Promise<FormState> {
  const user = await requireUser();
  try {
    await sendFriendRequest(user, friendRequestSchema.parse({ username }).username);
  } catch (error) {
    return formError(error);
  }
  refresh();
  return { ok: true };
}

export async function acceptFriendRequestAction(requestId: string, _prev: FormState): Promise<FormState> {
  const user = await requireUser();
  try {
    await acceptFriendRequest(user.id, z.guid().parse(requestId));
  } catch (error) {
    return formError(error);
  }
  refresh();
  return { ok: true };
}

export async function deleteFriendRequestAction(requestId: string, _prev: FormState): Promise<FormState> {
  const user = await requireUser();
  try {
    await deleteFriendRequest(user.id, z.guid().parse(requestId));
  } catch (error) {
    return formError(error);
  }
  refresh();
  return { ok: true };
}

export async function removeFriendAction(userId: string, _prev: FormState): Promise<FormState> {
  const user = await requireUser();
  await removeFriend(user.id, z.guid().parse(userId));
  refresh();
  return { ok: true };
}
