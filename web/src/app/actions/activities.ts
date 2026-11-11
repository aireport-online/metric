"use server";

import { randomUUID } from "node:crypto";
import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { ACTIVITY_TYPES, VISIBILITIES } from "@/lib/constants";
import { fromLocalInputValue } from "@/lib/format";
import { activityInputSchema, activityPatchSchema, commentSchema } from "@/lib/schemas";
import {
  addComment,
  deleteActivity,
  deleteComment,
  listFeed,
  listOwnActivities,
  setKudos,
  updateActivity,
  upsertActivity,
} from "@/server/activities";
import { ApiError } from "@/server/errors";
import { formError, formOk, type FormState } from "@/server/form";
import { getTimeZone, requireUser } from "@/server/session";

const text = (form: FormData, name: string) => String(form.get(name) ?? "").trim();

/** "45", "1:30" (u:mm) or "1:30:00" → seconds. */
function parseDuration(hours: string, minutes: string): number {
  const h = hours === "" ? 0 : Number(hours);
  const m = minutes === "" ? 0 : Number(minutes);
  if (!Number.isFinite(h) || !Number.isFinite(m) || h < 0 || m < 0) {
    throw new ApiError(400, "invalid_request", "Vul een geldige duur in.");
  }
  const seconds = Math.round(h * 3600 + m * 60);
  if (seconds < 60) throw new ApiError(400, "invalid_request", "Vul in hoe lang je bezig was.");
  return seconds;
}

export async function createActivityAction(_prev: FormState, form: FormData): Promise<FormState> {
  const user = await requireUser();
  let id: string;
  try {
    const startedAt = fromLocalInputValue(text(form, "startedAt"), await getTimeZone());
    if (!startedAt) throw new ApiError(400, "invalid_request", "Vul een datum en tijd in.");
    if (startedAt.getTime() > Date.now() + 5 * 60 * 1000) {
      throw new ApiError(400, "invalid_request", "De starttijd ligt in de toekomst.");
    }
    const km = text(form, "distanceKm").replace(",", ".");
    if (km !== "" && !(Number(km) >= 0)) throw new ApiError(400, "invalid_request", "Vul een geldige afstand in.");

    const input = activityInputSchema.parse({
      clientId: randomUUID(),
      type: text(form, "type"),
      title: text(form, "title"),
      notes: text(form, "notes"),
      startedAt: startedAt.toISOString(),
      durationSeconds: parseDuration(text(form, "hours"), text(form, "minutes")),
      distanceMeters: km === "" || Number(km) === 0 ? null : Number(km) * 1000,
      source: "web",
      visibility: text(form, "visibility") || undefined,
    });
    id = (await upsertActivity(user, input)).activity.id;
  } catch (error) {
    return formError(error, form);
  }
  redirect(`/activities/${id}`);
}

const editSchema = activityPatchSchema.extend({
  type: z.enum(ACTIVITY_TYPES).optional(),
  visibility: z.enum(VISIBILITIES).optional(),
});

export async function updateActivityAction(id: string, _prev: FormState, form: FormData): Promise<FormState> {
  const user = await requireUser();
  try {
    const patch = editSchema.parse({
      title: text(form, "title"),
      notes: text(form, "notes"),
      visibility: text(form, "visibility") || undefined,
      type: text(form, "type") || undefined,
    });
    await updateActivity(user.id, z.guid().parse(id), patch);
  } catch (error) {
    return formError(error, form);
  }
  redirect(`/activities/${id}`);
}

export async function deleteActivityAction(id: string) {
  const user = await requireUser();
  await deleteActivity(user.id, z.guid().parse(id));
  redirect("/activities");
}

export async function setKudosAction(id: string, on: boolean) {
  const user = await requireUser();
  return setKudos(user.id, z.guid().parse(id), on);
}

export async function addCommentAction(id: string, _prev: FormState, form: FormData): Promise<FormState> {
  const user = await requireUser();
  try {
    const { body } = commentSchema.parse({ body: text(form, "body") });
    await addComment(user, z.guid().parse(id), body);
  } catch (error) {
    return formError(error, form);
  }
  refresh();
  return formOk();
}

export async function deleteCommentAction(commentId: string) {
  const user = await requireUser();
  await deleteComment(user.id, z.guid().parse(commentId));
  refresh();
}

const cursor = z.iso.datetime({ offset: true });

export async function loadFeedAction(before: string) {
  const user = await requireUser();
  return listFeed(user.id, { before: new Date(cursor.parse(before)), limit: 20, withRoutePreview: true });
}

export async function loadOwnActivitiesAction(before: string) {
  const user = await requireUser();
  return listOwnActivities(user.id, { before: new Date(cursor.parse(before)), limit: 30 });
}
