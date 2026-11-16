import { Stack, Select, Group, ActionIcon, Tooltip } from '@mantine/core';
import { TbVolume } from 'react-icons/tb';
import { useSetters, useStore } from '../../../../store';
import { fetchNui } from '../../../../utils/fetchNui';

const Sound: React.FC = () => {
  const sounds = useSetters((state) => state.sounds);
  const lockSound = useStore((state) => state.lockSound);
  const unlockSound = useStore((state) => state.unlockSound);
  const setLockSound = useSetters((setter) => setter.setLockSound);
  const setUnlockSound = useSetters((setter) => setter.setUnlockSound);

  const previewSound = (soundName: string | null | undefined) => {
    if (soundName) {
      fetchNui('previewSound', { soundName });
    }
  };

  return (
    <Stack>
      <Group align="flex-end" spacing="xs" noWrap>
        <Select
          sx={{ flexGrow: 1 }}
          data={sounds}
          label="Lock sound"
          value={lockSound || ''}
          searchable
          clearable
          nothingFound="No such sound"
          onChange={(e) => setLockSound(e)}
        />
        <Tooltip label="Preview sound">
          <ActionIcon
            color="blue"
            variant="light"
            size="lg"
            disabled={!lockSound}
            onClick={() => previewSound(lockSound)}
            mb={3}
          >
            <TbVolume size={20} />
          </ActionIcon>
        </Tooltip>
      </Group>

      <Group align="flex-end" spacing="xs" noWrap>
        <Select
          sx={{ flexGrow: 1 }}
          data={sounds}
          label="Unlock sound"
          value={unlockSound || ''}
          searchable
          clearable
          nothingFound="No such sound"
          onChange={(e) => setUnlockSound(e)}
        />
        <Tooltip label="Preview sound">
          <ActionIcon
            color="blue"
            variant="light"
            size="lg"
            disabled={!unlockSound}
            onClick={() => previewSound(unlockSound)}
            mb={3}
          >
            <TbVolume size={20} />
          </ActionIcon>
        </Tooltip>
      </Group>
    </Stack>
  );
};

export default Sound;
