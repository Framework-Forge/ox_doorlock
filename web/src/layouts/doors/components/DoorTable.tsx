import {
  Accordion,
  Badge,
  Box,
  Button,
  Center,
  Group,
  Pagination,
  ScrollArea,
  Stack,
  Table,
  Text,
  ThemeIcon,
  UnstyledButton,
} from '@mantine/core';
import {
  ColumnDef,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  Row,
  SortingState,
  useReactTable,
} from '@tanstack/react-table';
import { useEffect, useMemo, useState } from 'react';
import {
  TbChevronDown,
  TbChevronUp,
  TbDoor,
  TbFolder,
  TbFolderOff,
  TbPlus,
  TbSearch,
  TbSelector,
} from 'react-icons/tb';
import { useNavigate } from 'react-router-dom';
import { defaultState, useStore } from '../../../store';
import { useDoors, type DoorColumn } from '../../../store/doors';
import { useSearch } from '../../../store/search';
import { normalizeDoorGroupName } from '../../../utils/doorGroups';
import ActionsMenu from './ActionsMenu';

const GROUPS_PER_PAGE = 6;

interface DoorSection {
  key: string;
  name: string | null;
  rows: Row<DoorColumn>[];
}

const DoorTable: React.FC = () => {
  const navigate = useNavigate();
  const [sorting, setSorting] = useState<SortingState>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const globalFilter = useSearch((state) => state.debouncedValue);
  const setSearchValue = useSearch((state) => state.setValue);
  const data = useDoors((state) => state.doors);

  const columns = useMemo<ColumnDef<DoorColumn>[]>(
    () => [
      {
        id: 'id',
        header: 'ID',
        accessorKey: 'id',
        cell: (info) => info.getValue(),
        enableGlobalFilter: false,
      },
      {
        id: 'name',
        header: 'Porta',
        accessorKey: 'name',
        cell: (info) => info.getValue(),
      },
      {
        id: 'doorGroup',
        header: 'Grupo',
        accessorKey: 'doorGroup',
        cell: (info) => info.getValue() || '-',
      },
      {
        id: 'zone',
        header: 'Localização',
        accessorKey: 'zone',
        cell: (info) => info.getValue(),
      },
      {
        id: 'options-menu',
        cell: (cell) => <ActionsMenu data={cell} />,
      },
    ],
    []
  );

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter },
    onGlobalFilterChange: setSearchValue,
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  });

  const rows = table.getRowModel().rows;

  const sections = useMemo<DoorSection[]>(() => {
    const grouped = new Map<string, DoorSection>();
    const ungrouped: Row<DoorColumn>[] = [];

    rows.forEach((row) => {
      const name = normalizeDoorGroupName(row.original.doorGroup);
      if (!name) {
        ungrouped.push(row);
        return;
      }

      const key = name.toLocaleLowerCase('pt-BR');
      const section = grouped.get(key);

      if (section) section.rows.push(row);
      else grouped.set(key, { key: `group-${key}`, name, rows: [row] });
    });

    const result = Array.from(grouped.values()).sort((left, right) =>
      (left.name || '').localeCompare(right.name || '', 'pt-BR')
    );

    if (ungrouped.length) result.push({ key: 'ungrouped', name: null, rows: ungrouped });
    return result;
  }, [rows]);

  const pageCount = Math.max(1, Math.ceil(sections.length / GROUPS_PER_PAGE));
  const visibleSections = sections.slice((currentPage - 1) * GROUPS_PER_PAGE, currentPage * GROUPS_PER_PAGE);

  useEffect(() => setCurrentPage(1), [globalFilter]);

  useEffect(() => {
    if (currentPage > pageCount) setCurrentPage(pageCount);
  }, [currentPage, pageCount]);

  const createDoorInGroup = (groupName: string | null) => {
    useStore.setState({ ...defaultState, doorGroup: groupName || '' }, true);
    navigate('/settings/general');
  };

  const renderTable = (groupRows: Row<DoorColumn>[]) => (
    <Table verticalSpacing="sm" horizontalSpacing="md" highlightOnHover>
      <thead>
        {table.getHeaderGroups().map((headerGroup) => (
          <tr key={headerGroup.id}>
            {headerGroup.headers.map((header) => {
              if (header.column.id === 'doorGroup') return null;
              return (
                <th key={header.id}>
                  <UnstyledButton onClick={header.column.getToggleSortingHandler()}>
                    <Group spacing={6} noWrap>
                      <Text size="xs" color="dimmed" weight={700} transform="uppercase">
                        {flexRender(header.column.columnDef.header, header.getContext())}
                      </Text>
                      {header.column.getIsSorted() === 'desc' ? (
                        <TbChevronDown />
                      ) : header.column.getIsSorted() === 'asc' ? (
                        <TbChevronUp />
                      ) : header.column.getCanSort() ? (
                        <TbSelector />
                      ) : null}
                    </Group>
                  </UnstyledButton>
                </th>
              );
            })}
          </tr>
        ))}
      </thead>
      <tbody>
        {groupRows.map((row) => (
          <tr key={row.id}>
            {row.getAllCells().map((cell) => {
              if (cell.column.id === 'doorGroup') return null;
              return <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>;
            })}
          </tr>
        ))}
      </tbody>
    </Table>
  );

  return (
    <Stack sx={{ flex: 1, minHeight: 0 }} spacing="sm" px="md" pb="md">
      {sections.length ? (
        <ScrollArea sx={{ flex: 1 }} offsetScrollbars>
          <Accordion multiple variant="separated" radius="md">
            {visibleSections.map((section) => {
              const isUngrouped = section.name === null;
              return (
                <Accordion.Item key={section.key} value={section.key}>
                  <Accordion.Control>
                    <Group position="apart" noWrap pr="xs">
                      <Group spacing="sm" noWrap>
                        <ThemeIcon variant="light" color={isUngrouped ? 'gray' : 'blue'} radius="md" size="lg">
                          {isUngrouped ? <TbFolderOff size={20} /> : <TbFolder size={20} />}
                        </ThemeIcon>
                        <Box>
                          <Text size="sm" weight={700}>
                            {section.name || 'Portas sem grupo'}
                          </Text>
                          <Text size="xs" color="dimmed">
                            {section.rows.length === 1 ? '1 porta cadastrada' : `${section.rows.length} portas cadastradas`}
                          </Text>
                        </Box>
                      </Group>
                      <Badge variant="filled" color={isUngrouped ? 'gray' : 'blue'} size="lg">
                        {section.rows.length}
                      </Badge>
                    </Group>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <Button
                      compact
                      mb="sm"
                      variant="light"
                      leftIcon={<TbPlus size={16} />}
                      onClick={() => createDoorInGroup(section.name)}
                    >
                      {isUngrouped ? 'Adicionar porta sem grupo' : `Adicionar porta em ${section.name}`}
                    </Button>
                    {renderTable(section.rows)}
                  </Accordion.Panel>
                </Accordion.Item>
              );
            })}
          </Accordion>
        </ScrollArea>
      ) : (
        <Center sx={{ flex: 1 }}>
          <Stack align="center" spacing="xs">
            <ThemeIcon variant="light" color="gray" radius="xl" size={72}>
              {globalFilter ? <TbSearch size={34} /> : <TbDoor size={34} />}
            </ThemeIcon>
            <Text size="lg" weight={700}>
              {globalFilter ? 'Nenhuma porta encontrada' : 'Nenhuma porta cadastrada'}
            </Text>
            <Text size="sm" color="dimmed">
              {globalFilter ? 'Tente buscar por outro nome, grupo ou localização.' : 'Crie a primeira porta para começar.'}
            </Text>
          </Stack>
        </Center>
      )}

      {pageCount > 1 && (
        <Group position="apart" px="xs">
          <Text size="xs" color="dimmed">
            Página {currentPage} de {pageCount} · {sections.length} grupos
          </Text>
          <Pagination page={currentPage} total={pageCount} onChange={setCurrentPage} size="sm" />
        </Group>
      )}
    </Stack>
  );
};

export default DoorTable;
