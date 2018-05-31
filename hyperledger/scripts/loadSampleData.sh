#!/bin/bash

ORIGINAL_PATH=$(pwd)
CURRENT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

NETWORK_NAME="black-poc"
NETWORK_ADMIN="admin"
NETWORK_ADMIN_SECRET="adminpw"
NETWORK_ADMIN_CARD="$NETWORK_ADMIN@$NETWORK_NAME"
NETWORK_ADMIN_CARD_PATH="$ORIGINAL_PATH/keys/black-poc/networkadmin.card"
INSTALLER_CARD="PeerAdmin@hlfv1"

PLATFORM_LAUNCHED_DATE=$(date --utc +%FT%TZ)
PLATFORM_SHUTDOWN_DATE="2018-08-01T00:00:00Z"
BLACK_INSURANCE_AGENCY_ID="BLACK_INSURANCE"
BLACK_INSURANCE_AGENCY_NAME="Black Insurance"
BLACK_INSURANCE_MANAGER_ID="BLACK_INSURANCE_MANAGER"
BLACK_INSURANCE_MANAGER_CARD="agencyManager@$NETWORK_NAME"
BLACK_INSURANCE_MANAGER_CARD_PATH="$ORIGINAL_PATH/keys/black-poc/agencymanager.card"
BROKER_ID="BROKER"
BROKER_CARD="broker@$NETWORK_NAME"
BROKER_CARD_PATH="$ORIGINAL_PATH/keys/black-poc/broker.card"
SYNDICATE_1_ID="SYNDICATE-1"
SYNDICATE_1_NAME="Syndicate One"
SYNDICATE_1_MANAGER_ID="SYNDICATE-1_MANAGER"
SYNDICATE_1_MANAGER_CARD="syndicateManager@$NETWORK_NAME"
SYNDICATE_1_MANAGER_CARD_PATH="$ORIGINAL_PATH/keys/black-poc/syndicatemanager.card"
RAIN_ORACLE_ID="RAIN_ORACLE"
RAIN_ORACLE_CARD="rainOracle@$NETWORK_NAME"
RAIN_ORACLE_CARD_PATH="$ORIGINAL_PATH/keys/black-poc/rainoracle.card"
RAINY_DAY_INSURANCE_ID="RAINY_DAY_INSURANCE"
RAINY_DAY_INSURANCE_NAME="Rainy Day Insurance"
INVESTOR_ID_PREFIX="INVESTOR-"
INVESTOR_NAME_PREFIX="investor-"
INVESTOR_CARD_PATH_PREFIX="$ORIGINAL_PATH/keys/black-poc/investor-"

BLCK_DEPOSITED_FOR_GAME=100000
NUMBER_OF_INVESTORS=10
BLCK_PER_INVESTOR=$(bc <<< "scale=10; $BLCK_DEPOSITED_FOR_GAME / $NUMBER_OF_INVESTORS")


# Only proceed if the NetworkAdmin identity exists, and all other identities are missing
if [ ! -f $NETWORK_ADMIN_CARD_PATH ]; then
    echo "The NetworkAdmin identity is missing and this prevents us from loading the Platform Data"
    exit 1
fi

if [[ -e $BROKER_CARD_PATH || -e $BLACK_INSURANCE_MANAGER_CARD_PATH || -e $SYNDICATE_1_MANAGER_CARD_PATH || -e $RAIN_ORACLE_PATH ]]; then
    echo "Located identity cards for users, created during a previous data load of the platform."
    echo "Do you want to delete and reload them?"
    exit 1
fi

# Make sure the Network is running
NETWORK_EXISTS=$(composer network ping --card $NETWORK_ADMIN_CARD | grep "Command succeeded" | wc -l)
if [ $NETWORK_EXISTS = "0" ]; then
    echo "The Fabric+Composer network is running properly.  Could not get a successful ping response from the network.  Will not attempt to load data"
    exit 1
fi

#: <<'END'
# Broker, AgencyManager, SyndicateManager, and RainOracle users all join the Platform
BROKER_PARTICIPANT=$(cat <<END_OF_BP
{"\$class":"insure.black.poc.PlatformUser",
    "type":"Broker",
    "participantID":"$BROKER_ID",
    "balanceBLCK":0}
END_OF_BP
)
composer participant add -c $NETWORK_ADMIN_CARD -d "$BROKER_PARTICIPANT"
composer identity issue -c $NETWORK_ADMIN_CARD -f $BROKER_CARD_PATH -u broker -a "resource:insure.black.poc.PlatformUser#$BROKER_ID"
composer card import --file $BROKER_CARD_PATH --name "$BROKER_CARD"

AGENCY_MANAGER_PARTICIPANT=$(cat <<END_OF_AMP
{"\$class":"insure.black.poc.PlatformUser",
    "type":"AgencyManager",
    "participantID":"$BLACK_INSURANCE_MANAGER_ID",
    "balanceBLCK":0}
END_OF_AMP
)
composer participant add -c $NETWORK_ADMIN_CARD -d "$AGENCY_MANAGER_PARTICIPANT"
composer identity issue -c $NETWORK_ADMIN_CARD -f $BLACK_INSURANCE_MANAGER_CARD_PATH -u agencyManager -a "resource:insure.black.poc.PlatformUser#$BLACK_INSURANCE_MANAGER_ID"
composer card import --file $BLACK_INSURANCE_MANAGER_CARD_PATH --name "$BLACK_INSURANCE_MANAGER_CARD"

SYNDICATE_MANAGER_PARTICIPANT=$(cat <<END_OF_SMP
{"\$class":"insure.black.poc.PlatformUser",
    "type":"SyndicateManager",
    "participantID":"$SYNDICATE_1_MANAGER_ID",
    "balanceBLCK":0}
END_OF_SMP
)
composer participant add -c $NETWORK_ADMIN_CARD -d "$SYNDICATE_MANAGER_PARTICIPANT"
composer identity issue -c $NETWORK_ADMIN_CARD -f $SYNDICATE_1_MANAGER_CARD_PATH -u syndicateManager -a "resource:insure.black.poc.PlatformUser#$SYNDICATE_1_MANAGER_ID"
composer card import --file $SYNDICATE_1_MANAGER_CARD_PATH --name "$SYNDICATE_1_MANAGER_CARD"

RAIN_ORACLE_PARTICIPANT=$(cat <<END_OF_ROP
{"\$class":"insure.black.poc.PlatformUser",
    "type":"Oracle",
    "participantID":"$RAIN_ORACLE_ID",
    "balanceBLCK":0}
END_OF_ROP
)
composer participant add -c $NETWORK_ADMIN_CARD -d "$RAIN_ORACLE_PARTICIPANT"
composer identity issue -c $NETWORK_ADMIN_CARD -f $RAIN_ORACLE_CARD_PATH -u rainOracle -a "resource:insure.black.poc.PlatformUser#$RAIN_ORACLE_ID"
composer card import --file $RAIN_ORACLE_CARD_PATH --name "$RAIN_ORACLE_CARD"

# Investors join the Platform with funded accounts
for i in `seq 1 $NUMBER_OF_INVESTORS`; 
do
    INVESTOR_PARTICIPANT=$(cat <<END_OF_IP
    {"\$class":"insure.black.poc.PlatformUser",
        "type":"Investor",
        "participantID":"$INVESTOR_ID_PREFIX$i",
        "balanceBLCK":"$BLCK_PER_INVESTOR"}
END_OF_IP
    )
    composer participant add -c $NETWORK_ADMIN_CARD -d "$INVESTOR_PARTICIPANT"
    composer identity issue -c $NETWORK_ADMIN_CARD -f "$INVESTOR_CARD_PATH_PREFIX$i.card" -u "$INVESTOR_NAME_PREFIX$i" -a "resource:insure.black.poc.PlatformUser#$INVESTOR_ID_PREFIX$i"
    composer card import --file "$INVESTOR_CARD_PATH_PREFIX$i.card" --name "$INVESTOR_NAME_PREFIX$i@$NETWORK_NAME"
done

# Syndicate Manager creates Syndicate One
SYNDICATE_1_PARTICIPANT=$(cat <<END_OF_S1P
{"\$class":"insure.black.poc.Syndicate",
    "name":"$SYNDICATE_1_NAME",
    "participantID":"$SYNDICATE_1_ID",
    "creationDate":"$PLATFORM_LAUNCHED_DATE",
    "dissolutionDate":"$PLATFORM_SHUTDOWN_DATE",
    "manager":"resource:insure.black.poc.PlatformUser#$SYNDICATE_1_MANAGER_ID",
    "claimSubmitter":"resource:insure.black.poc.PlatformUser#$RAIN_ORACLE_ID",
    "balanceBLCK":0,
    "fundingTarget":$BLCK_DEPOSITED_FOR_GAME}
END_OF_S1P
)
composer participant add -c "$SYNDICATE_1_MANAGER_CARD" -d "$SYNDICATE_1_PARTICIPANT"

# Each Investor invests in the Syndicate
for i in `seq 1 $NUMBER_OF_INVESTORS`; 
do
    INVESTOR_INVEST_IN_SYNDICATE_TRANSACTION=$(cat <<END_OF_IIST
    {"\$class":"insure.black.poc.InvestInSyndicate",
        "investmentAmount":$BLCK_PER_INVESTOR,
        "investor":"resource:insure.black.poc.PlatformUser#$INVESTOR_ID_PREFIX$i",
        "syndicate":"resource:insure.black.poc.Syndicate#$SYNDICATE_1_ID"}
END_OF_IIST
    )
    composer transaction submit --card "$INVESTOR_NAME_PREFIX$i@$NETWORK_NAME" -d "$INVESTOR_INVEST_IN_SYNDICATE_TRANSACTION"
done

# Agency Manager creates the Rainy Day Insurance Product
RAINY_DAY_INSURANCE_PRODUCT_ASSET=$(cat <<END_OF_RDIPA
{"\$class": "org.hyperledger.composer.system.AddAsset",
    "registryType": "Asset",
    "registryId": "insure.black.poc.Product",
    "targetRegistry" : "resource:org.hyperledger.composer.system.AssetRegistry#insure.black.poc.Product",
    "resources": [
        {"\$class": "insure.black.poc.Product",
            "productID": "$RAINY_DAY_INSURANCE_ID",
            "name": "$RAINY_DAY_INSURANCE_NAME",
            "description": "Insurance that will pay you 1 BLCK token each day that the city covered by an active Policy receives 10mm or more of rain within a 24 hour period.  Max coverage of 100 BLCK for any single Policy.",
            "productDetailURL": "https://wwww.black.insure/",
            "creator": "resource:insure.black.poc.PlatformUser#$BLACK_INSURANCE_MANAGER_ID"
        }]}
END_OF_RDIPA
)
composer transaction submit --card "$BLACK_INSURANCE_MANAGER_CARD" -d "$RAINY_DAY_INSURANCE_PRODUCT_ASSET"

# Agency Manager creates the Black Insurance Agency, seeking to sell 2M in Rainy Day Insurance Policies
BLACK_INSURANCE_AGENCY_PARTICIPANT=$(cat <<END_OF_BIAP
{"\$class":"insure.black.poc.InsuranceAgency",
    "name":"$BLACK_INSURANCE_AGENCY_NAME",
    "participantID":"$BLACK_INSURANCE_AGENCY_ID",
    "creationDate":"$PLATFORM_LAUNCHED_DATE",
    "dissolutionDate":"$PLATFORM_SHUTDOWN_DATE",
    "policySalesTarget":2000000,
    "productForSale": "resource:insure.black.poc.Product#$RAINY_DAY_INSURANCE_ID",
    "manager":"resource:insure.black.poc.PlatformUser#$BLACK_INSURANCE_MANAGER_ID",
    "broker":"resource:insure.black.poc.PlatformUser#$BROKER_ID",
    "claimSubmitter":"resource:insure.black.poc.PlatformUser#$RAIN_ORACLE_ID",
    "balanceBLCK":0}
END_OF_BIAP
)
composer participant add -c "$BLACK_INSURANCE_MANAGER_CARD" -d "$BLACK_INSURANCE_AGENCY_PARTICIPANT"

# Syndicate Manager agrees to underwrite Rainy Day Insurance Policies sold by Black Insurance
SYNDICATE_UNDERWRITES_POLICIES_TRANSACTION=$(cat <<END_OF_SUPT
{"\$class":"insure.black.poc.UnderwritePolicies",
    "underwritingAmount":2000000,
    "agency":"resource:insure.black.poc.InsuranceAgency#$BLACK_INSURANCE_AGENCY_ID",
    "syndicate":"resource:insure.black.poc.Syndicate#$SYNDICATE_1_ID"}
END_OF_SUPT
)
composer transaction submit --card "$SYNDICATE_1_MANAGER_CARD" -d "$SYNDICATE_UNDERWRITES_POLICIES_TRANSACTION"
#END

