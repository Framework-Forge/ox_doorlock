import type { DoorColumn } from '../store/doors';

export const normalizeDoorGroupName = (value?: string | null): string =>
  (value || '').trim().replace(/\s+/g, ' ');

export const getDoorGroupNames = (doors: DoorColumn[]): string[] => {
  const groups = new Map<string, string>();

  doors.forEach((door) => {
    const name = normalizeDoorGroupName(door.doorGroup);
    if (!name) return;

    const key = name.toLocaleLowerCase('pt-BR');
    if (!groups.has(key)) groups.set(key, name);
  });

  return Array.from(groups.values()).sort((left, right) => left.localeCompare(right, 'pt-BR'));
};
