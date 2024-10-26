Structure of the LOCAL folder is as follows:

- **\\**: Root files
  - **docker-compose-$HOSTNAME.yml**: One docker-compose file for every Host.
  - **.env.example**: Example of a .env file. This file should be copied to the local .env file for use.

- **appdata**: Contains application specific data for every service installed by Docker. Folder format is:
  - **AppName**\: Application specific data

  - **traefik**\: Application specific data
    - **rules**: Traefik Rules
      - **$HOSTNAME**: Contains Traefik rules for the $HOSTNAME host      

- **include**: Contains includable docker-compose YML files. These are referenced by the docker-compose-$HOSTNAME.yml file.
  - **$HOSTNAME**\: Contains included files for the specific $HOSTNAME

- **secrets_example**: Contains examples of various secret files. Files in this folder should be copied to the local "secrets" folder for use

- **archive**: Contains archived files from other folders.
  
