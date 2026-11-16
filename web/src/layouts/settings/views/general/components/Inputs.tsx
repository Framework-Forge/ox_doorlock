import { Box, Grid, Select, Text } from '@mantine/core';
import { useEffect, useMemo, useState } from 'react';
import Input from './Input';
import { useSetters, useStore } from '../../../../../store';
import { useDoors } from '../../../../../store/doors';
import { getDoorGroupNames, normalizeDoorGroupName } from '../../../../../utils/doorGroups';

const Inputs: React.FC = () => {
  const doorName = useStore((state) => state.name);
  const doorGroup = useStore((state) => state.doorGroup);
  const passcode = useStore((state) => state.passcode);
  const autolockInterval = useStore((state) => state.autolock);
  const interactDistance = useStore((state) => state.maxDistance);
  const doorRate = useStore((state) => state.doorRate);
  const doorType = useStore((state) => state.doorType);
  const doors = useDoors((state) => state.doors);
  const [doorGroupSearch, setDoorGroupSearch] = useState(doorGroup || '');
  const doorGroups = useMemo(
    () => getDoorGroupNames(doors).map((name) => ({ value: name, label: name })),
    [doors]
  );

  const setDoorName = useSetters((setter) => setter.setName);
  const setDoorGroup = useSetters((setter) => setter.setDoorGroup);
  const setPasscode = useSetters((setter) => setter.setPasscode);
  const setAutolockInterval = useSetters((setter) => setter.setAutolock);
  const setInteractDistance = useSetters((setter) => setter.setMaxDistance);
  const setDoorRate = useSetters((setter) => setter.setDoorRate);
  const setDoorType = useSetters((setter) => setter.setDoorType);

  useEffect(() => {
    setDoorGroupSearch(doorGroup || '');
  }, [doorGroup]);

  const commitDoorGroup = (value: string | null | undefined) => {
    const name = normalizeDoorGroupName(value);
    setDoorGroup(name);
    setDoorGroupSearch(name);
  };

  return (
    <Grid columns={2} sx={{ fontSize: 16 }}>
      <Input label="Door name" type="text" value={doorName || ''} setValue={(value: string) => setDoorName(value)} />
      <Grid.Col span={1}>
        <Select
          label="Grupo de portas"
          placeholder="Selecione ou crie um grupo"
          value={doorGroup || null}
          searchValue={doorGroupSearch}
          onSearchChange={setDoorGroupSearch}
          data={doorGroups}
          searchable
          clearable
          creatable
          nothingFound="Nenhum grupo encontrado"
          getCreateLabel={(query) => `+ Criar grupo “${normalizeDoorGroupName(query)}”`}
          onCreate={(query) => {
            const name = normalizeDoorGroupName(query);
            commitDoorGroup(name);
            return { value: name, label: name };
          }}
          onChange={commitDoorGroup}
          onBlur={() => commitDoorGroup(doorGroupSearch)}
        />
        <Text size="xs" color="dimmed" mt={4}>
          Este grupo organiza portas. Permissões de emprego e gangue ficam na aba “Groups”.
        </Text>
      </Grid.Col>
      <Input label="Passcode" type="text" value={passcode || ''} setValue={(value: string) => setPasscode(value)} />
      <Input
        label="Autolock Interval"
        type="number"
        value={autolockInterval || 0}
        setValue={(value: number) => setAutolockInterval(value)}
        infoCircle="Time in seconds after which the door will be locked"
      />
      <Input
        label="Interact Distance"
        type="number"
        value={interactDistance || 0}
        setValue={(value: number) => setInteractDistance(value)}
        infoCircle="Controls the distance from which the player can interact with the door"
      />
      <Input
        label="Door Rate"
        type="number"
        value={doorRate || 0}
        setValue={(value: number) => setDoorRate(value)}
        infoCircle="Speed the automatic door will move at"
      />
      <Grid.Col span={1}>
        <Box>
          <Select
            label="Door Type"
            value={doorType || 'normal'}
            onChange={(value) => setDoorType(value as 'normal' | 'rotate' | 'slide')}
            data={[
              { value: 'normal', label: 'Normal' },
              { value: 'rotate', label: 'Rotate' },
              { value: 'slide', label: 'Slide' },
            ]}
          />
        </Box>
      </Grid.Col>
    </Grid>
  );
};

export default Inputs;
