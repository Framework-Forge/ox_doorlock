import { Button, CloseButton, createStyles, Group, Tooltip } from '@mantine/core';
import { TbPlus } from 'react-icons/tb';
import { useNavigate } from 'react-router-dom';
import { useVisibility } from '../../../store/visibility';
import { fetchNui } from '../../../utils/fetchNui';
import Searchbar from './Search';
import { useStore, defaultState } from '../../../store';

const useStyles = createStyles({
  main: {
    display: 'flex',
    justifyContent: 'flex-start',
    alignItems: 'center',
    padding: 18,
    paddingBottom: 10,
    borderBottom: '1px solid rgba(255, 255, 255, 0.06)',
  },
});

const Header: React.FC = () => {
  const { classes } = useStyles();
  const navigate = useNavigate();
  const setVisible = useVisibility((state) => state.setVisible);

  return (
    <Group className={classes.main}>
      <Tooltip label="Criar uma porta sem grupo" transition="pop">
        <Button
          variant="gradient"
          gradient={{ from: 'blue.7', to: 'cyan.6', deg: 120 }}
          color="blue"
          leftIcon={<TbPlus size={18} />}
          onClick={() => {
            useStore.setState(defaultState, true);
            navigate('/settings/general');
          }}
        >
          Nova porta
        </Button>
      </Tooltip>
      <Searchbar />
      <CloseButton
        iconSize={20}
        size="lg"
        onClick={() => {
          setVisible(false);
          fetchNui('exit');
        }}
      />
    </Group>
  );
};

export default Header;
