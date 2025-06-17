adminer_module = import_module("github.com/bharath-123/db-adminer-package/main.star")

PORT_NAME = "postgresql"
APPLICATION_PROTOCOL = "postgresql"
PG_DRIVER = "pgsql"

CONFIG_FILE_MOUNT_DIRPATH = "/config"
SEED_FILE_MOUNT_PATH = "/docker-entrypoint-initdb.d"
DATA_DIRECTORY_PATH = "/data/"

CONFIG_FILENAME = "postgresql.conf"  # Expected to be in the artifact

POSTGRES_MIN_CPU = 10
POSTGRES_MAX_CPU = 1000
POSTGRES_MIN_MEMORY = 32
POSTGRES_MAX_MEMORY = 1024


def run(
    plan,
    image="postgres:alpine",
    service_name="postgres",
    user="postgres",
    password="MyPassword1!",
    database="postgres",
    config_file_artifact_name="",
    seed_file_artifact_name="",
    extra_configs=[],
    extra_env_vars={},
    persistent=True,
    launch_adminer=False,
    min_cpu=POSTGRES_MIN_CPU,
    max_cpu=POSTGRES_MAX_CPU,
    min_memory=POSTGRES_MIN_MEMORY,
    max_memory=POSTGRES_MAX_MEMORY,
    node_selectors=None,
):
    plan.print("Running postgres package")
    cmd = []
    files = {}
    env_vars = {
        "POSTGRES_DB": database,
        "POSTGRES_USER": user,
        "POSTGRES_PASSWORD": password,
    }

    # Add extra env vars
    for k, v in extra_env_vars.items():
        env_vars[k] = v

    if persistent:
        plan.print("Using /data folder")
        env_vars["PGDATA"] = DATA_DIRECTORY_PATH + "pgdata"
    if node_selectors == None:
        node_selectors = {}
    if config_file_artifact_name != "":
        config_filepath = CONFIG_FILE_MOUNT_DIRPATH + "/" + CONFIG_FILENAME
        cmd += ["-c", "config_file=" + config_filepath]
        files[CONFIG_FILE_MOUNT_DIRPATH] = config_file_artifact_name

    # append cmd with postgres config overrides passed by users
    if len(extra_configs) > 0:
        for config in extra_configs:
            cmd += ["-c", config]

    if seed_file_artifact_name != "":
        files[SEED_FILE_MOUNT_PATH] = seed_file_artifact_name

    postgres_service = plan.add_service(
        name=service_name,
        config=ServiceConfig(
            image=image,
            ports={
                PORT_NAME: PortSpec(
                    number=5432,
                    application_protocol=APPLICATION_PROTOCOL,
                )
            },
            cmd=cmd,
            files=files,
            env_vars=env_vars,
            min_cpu=min_cpu,
            max_cpu=max_cpu,
            min_memory=min_memory,
            max_memory=max_memory,
            node_selectors=node_selectors,
        ),
    )

    if launch_adminer:
        adminer = adminer_module.run(
            plan,
            default_db=database,
            default_driver=PG_DRIVER,
            default_password=password,
            default_server=postgres_service.hostname,
            default_username=user,
        )

    url = "{protocol}://{user}:{password}@{hostname}/{database}".format(
        protocol=APPLICATION_PROTOCOL,
        user=user,
        password=password,
        hostname=postgres_service.hostname,
        database=database,
    )

    return struct(
        url=url,
        service=postgres_service,
        port=postgres_service.ports[PORT_NAME],
        user=user,
        password=password,
        database=database,
        min_cpu=min_cpu,
        max_cpu=max_cpu,
        min_memory=min_memory,
        max_memory=max_memory,
        node_selectors=node_selectors,
    )


def run_query(plan, service, user, password, database, query):
    url = "{protocol}://{user}:{password}@{hostname}/{database}".format(
        protocol=APPLICATION_PROTOCOL,
        user=user,
        password=password,
        hostname=service.hostname,
        database=database,
    )
    return plan.exec(
        service.name, recipe=ExecRecipe(command=["psql", url, "-c", query])
    )
