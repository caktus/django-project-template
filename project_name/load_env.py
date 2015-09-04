from os.path import dirname, join
import dotenv

project_dir = dirname(dirname(__file__))
dotenv.read_dotenv(join(project_dir, '.env'))
