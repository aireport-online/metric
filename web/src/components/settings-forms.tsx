"use client";

import { useActionState, useState } from "react";
import { deleteAccountAction, updateProfileAction } from "@/app/actions/auth";
import { VISIBILITY_LABEL } from "@/lib/activity-types";
import { VISIBILITIES, type Visibility } from "@/lib/constants";
import { ConfirmSubmit, SubmitButton } from "./client-bits";
import { FormMessage } from "./ui";

function SaveRow({ state }: { state: { error?: string; ok?: boolean } | undefined }) {
  return (
    <div className="flex items-center justify-end gap-3">
      <FormMessage state={state} />
      {state?.ok ? (
        <span role="status" className="text-muted">
          Opgeslagen
        </span>
      ) : null}
      <SubmitButton pendingLabel="Opslaan…">Opslaan</SubmitButton>
    </div>
  );
}

export function ProfileForm({ displayName, bio }: { displayName: string; bio: string }) {
  const [state, action] = useActionState(updateProfileAction, undefined);
  return (
    <form action={action} key={state?.nonce ?? "form"} className="flex flex-col gap-4">
      <div>
        <label htmlFor="displayName" className="label">
          Naam
        </label>
        <input id="displayName" name="displayName" required maxLength={50} defaultValue={state?.values?.displayName ?? displayName} className="input" />
      </div>
      <div>
        <label htmlFor="bio" className="label">
          Over jou
        </label>
        <textarea id="bio" name="bio" rows={3} maxLength={280} defaultValue={state?.values?.bio ?? bio} className="input" />
      </div>
      <SaveRow state={state} />
    </form>
  );
}

export function GoalForm({ weeklyGoalMinutes }: { weeklyGoalMinutes: number }) {
  const [state, action] = useActionState(updateProfileAction, undefined);
  const [minutes, setMinutes] = useState(weeklyGoalMinutes);
  const sessions = Math.max(1, Math.round(minutes / 30));
  return (
    <form action={action} className="flex flex-col gap-4">
      <div>
        <label htmlFor="weeklyGoalMinutes" className="label">
          Minuten per week
        </label>
        <div className="flex items-center gap-3">
          <input
            id="weeklyGoalMinutes"
            name="weeklyGoalMinutes"
            type="number"
            inputMode="numeric"
            min={10}
            max={3000}
            step={5}
            required
            value={Number.isFinite(minutes) ? minutes : ""}
            onChange={(event) => setMinutes(event.target.valueAsNumber)}
            className="input num max-w-[140px]"
            aria-describedby="goal-preview"
          />
          <p id="goal-preview" className="num text-muted">
            {Number.isFinite(minutes) && minutes >= 10
              ? `Dat is ongeveer ${sessions} × 30 minuten, of ${Math.round(minutes / 7)} minuten per dag.`
              : "Kies een doel van minstens 10 minuten."}
          </p>
        </div>
      </div>
      <SaveRow state={state} />
    </form>
  );
}

const VISIBILITY_HELP: Record<Visibility, string> = {
  private: "Nieuwe activiteiten zie alleen jij, tot je ze zelf deelt.",
  friends: "Nieuwe activiteiten verschijnen in de feed van je vrienden.",
  public: "Nieuwe activiteiten zijn te zien voor iedereen die de link of je profiel opent.",
};

export function VisibilityForm({ defaultVisibility }: { defaultVisibility: Visibility }) {
  const [state, action] = useActionState(updateProfileAction, undefined);
  const selected = state?.values?.defaultVisibility ?? defaultVisibility;
  return (
    <form action={action} key={state?.nonce ?? "form"} className="flex flex-col gap-4">
      <fieldset className="flex flex-col gap-1">
        <legend className="label">Nieuwe activiteiten zijn zichtbaar voor</legend>
        {VISIBILITIES.map((visibility) => (
          <label key={visibility} className="flex min-h-11 cursor-pointer items-start gap-3 py-1.5">
            <input type="radio" name="defaultVisibility" value={visibility} defaultChecked={visibility === selected} className="mt-1 h-4 w-4" />
            <span>
              <span className="block font-medium">{VISIBILITY_LABEL[visibility]}</span>
              <span className="block text-muted">{VISIBILITY_HELP[visibility]}</span>
            </span>
          </label>
        ))}
      </fieldset>
      <SaveRow state={state} />
    </form>
  );
}

export function DeleteAccountForm({ username }: { username: string }) {
  const [state, action] = useActionState(deleteAccountAction, undefined);
  return (
    <form action={action} className="flex flex-col gap-4">
      <div>
        <label htmlFor="delete-password" className="label">
          Wachtwoord ter bevestiging
        </label>
        <input id="delete-password" name="password" type="password" autoComplete="current-password" required className="input max-w-[320px]" />
      </div>
      <div className="flex items-center justify-end gap-3">
        <FormMessage state={state} />
        <ConfirmSubmit message={`Account @${username} en alle activiteiten definitief verwijderen? Dit kan niet ongedaan worden gemaakt.`}>
          Account @{username} verwijderen
        </ConfirmSubmit>
      </div>
    </form>
  );
}
