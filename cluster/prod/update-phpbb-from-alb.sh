ALB_NAME=$1
PHPBB_POD=$2
DB_HOST=$3
DB_USER=$4
DB_NAME=$5
PORT=${6:-80}   # default to 80 if not provided

if [[ -z "$ALB_NAME" || -z "$PHPBB_POD" || -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_NAME" ]]; then
  echo "Usage: $0 <alb-name> <phpbb-pod> <db-host> <db-user> <db-name> [port]"
    exit 1
    fi

    # Get the ALB DNS from AWS CLI
    ALB_DNS=$(aws elbv2 describe-load-balancers \
      --names "$ALB_NAME" \
        --query "LoadBalancers[0].DNSName" \
	  --output text)

	  if [[ -z "$ALB_DNS" ]]; then
	    echo "Error: Could not find ALB with name $ALB_NAME"
	      exit 1
	      fi

	      echo "Found ALB DNS: $ALB_DNS"

	      # Prompt for DB password securely
	      read -s -p "Enter DB password for $DB_USER@$DB_HOST: " DB_PASS
	      echo

	      # Build SQL commands
	      SQL=$(cat <<EOF
	      UPDATE phpbb_config
	      SET config_value = '${ALB_DNS}'
	      WHERE config_name = 'server_name';

	      UPDATE phpbb_config
	      SET config_value = '${PORT}'
	      WHERE config_name = 'server_port';

	      UPDATE phpbb_config
	      SET config_value = '1'
	      WHERE config_name = 'force_server_vars';

	      UPDATE phpbb_config
	      SET config_value = '${ALB_DNS}'
	      WHERE config_name = 'cookie_domain';

	      UPDATE phpbb_config
	      SET config_value = '/'
	      WHERE config_name = 'cookie_path';

	      UPDATE phpbb_config
	      SET config_value = CASE WHEN '${PORT}' = '443' THEN '1' ELSE '0' END
	      WHERE config_name = 'cookie_secure';

	      UPDATE phpbb_config
	      SET config_value = CASE WHEN '${PORT}' = '443' THEN 'https://' ELSE 'http://' END
	      WHERE config_name = 'server_protocol';
	      EOF
	      )

	      # Execute SQL against the database
	      PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "$SQL"

	      # Clear phpBB cache
	      echo "Clearing phpBB cache..."
	      kubectl exec -it "$PHPBB_POD" -- rm -rf /var/www/html/phpbb/cache/*

	      echo "phpBB updated to new ALB domain: $ALB_DNS"

