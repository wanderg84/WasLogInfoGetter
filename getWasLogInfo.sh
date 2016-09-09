#!/bin/sh

printLogInfo() {

        if [ ! -d "$1" ]; then
               return;
        fi
        cd $1

        echo "log conf file path : "
        find $PWD \( -name "log*.xml" -o -name "log*.properties" \)

        logConfPath=$(find $PWD -name "log*.xml" )
        logPropertiesPath=$(find $PWD -name "log*.properties")
        echo

        #logConf에 사용된 property 값 찾기
        for logProperties in $logPropertiesPath
        do
                if [[ $logProperties =~ -(local|dev|qa|stg|real).properties && ! -z $profile  && !($logProperties =~ $profile.properties) ]]
                then
                        continue;
                fi

                echo "logProperties info : $logProperties"

                if [ -f "$logProperties" ]
                then
                         while IFS='=' read -r key value
                        do
                                if [[ -z $key ]]
                                then
                                        continue;
                                fi

                                key=$(echo $key | tr '.' '_')
                                eval "${key}='${value}'"
                         done < "$logProperties"
                fi
        done
        echo


        #logPath 관련 정보 추출
        for logConf in $logConfPath
        do
                if [[ $logConf =~ -(local|dev|qa|stg|real).xml && ! -z $profile  && !($logConf =~ $profile.xml )  ]]
                then
                        continue;
                fi

		echo "------------------------------------------------------------------------------------------------"
                echo "logPath info : $logConf"
		echo "------------------------------------------------------------------------------------------------"
                
		logFileInfos=$(cat $logConf | grep -o -i -e '<file>.*</file>' -e '<fileNamePattern>.*</fileNamePattern>' -e '<appender .*>' -e '<param name="File".*>' -e '<param name="DatePattern".*>')

                while read -r line;
                do
                        #echo "source : $line"
                        #replaced=$(echo $line | sed 's/\./_/g') 
                        #result=$(echo $(eval "echo \"$replaced\" ") | sed 's/\./_/g'); #$(injectPropertiesValue $line)
                        #echo processing : $(eval "echo \"$result\" ");
                        #replacePropertiesDot "$line";
			if [[ $line =~ appender ]]
			then
				echo
			fi
			injectPropertiesValue "$line";

                done <<< "$logFileInfos"

                echo "------------------------------------------------------------------------------------------------"
		echo; echo;
        done
}

injectPropertiesValue() {
        replaced=$(replacePropertiesDot "$1");
        result=$(eval "echo \"$replaced\" ");

        if [[ $result =~ \$\{.* ]]
        then
                echo "=> $result"
                injectPropertiesValue "$result" 
        else
                echo $result 
        fi
}

replacePropertiesDot() {

        result=$1
        if [[ $result =~ \$\{.* ]]
        then

                propertyNames=$(echo "$1" | grep -Po '\$\{[a-zA-Z0-9/-_\.]*\}');
                while read -r propertyName
                do
                        convertedPropName=$(echo $propertyName | sed 's/\./_/g');
                        result=$(echo $result | sed "s/${propertyName}/${convertedPropName}/g")

                done <<< "$propertyNames"
        fi

        echo $result;
}

while getopts "h?lp:e:" opt; do
    case "$opt" in
    h|\?)
        echo " getAppLogInfo.sh -pname tsacOneSvr1 -profile stg"
        echo " pname : processName, profile : local/dev/qa/stg/real"
        exit 0
        ;;
    l)
        ps -ef | grep '[j]ava.*tomcat.*start' $optProcess | grep -o -e 'config.file=.*logging.properties' | sed 's/config.file=\|logging.properties//g' | sed 's/\/conf//g';
        exit 0
        ;;
        p)  processName=$OPTARG;
        ;;
    e) profile=$OPTARG
        ;;
    esac
done

psList=$(ps -ef | grep '[j]ava.*tomcat.*start') 
if [[ ! -z $processName ]] 
then
        psList=$(ps -ef | grep '[j]ava.*tomcat.*start' | grep -i $processName) 
fi

while read -r line
do
        confDir=$(echo $line | grep -o -e 'config.file=.*logging.properties' | sed 's/config.file=\|logging.properties//g' )

        echo "============================================================================"
        #echo $line
        echo $line | grep -o -e '-D[^\\[:space:]]*' | grep -e 'name' -e 'profile'
        echo tomcat directory : $(echo $confDir | sed 's/\/conf//g')
        echo "============================================================================"

        echo "java opt :"
        echo $line | grep -o -e '-D[^\\[:space:]]*'
        echo

        echo "tomcat conf directory : $confDir"
        echo

        cd $confDir
        appBase=$(grep -o -e 'appBase=[^\\[:space:]]*' server.xml  | sed 's/appBase=\|"//g')
        docBase=$(grep -o -e 'docBase=[^\\[:space:]]*' server.xml  | sed 's/docBase=\|"//g')
        echo "appBase : $appBase, docBase : $docBase"
        echo

        printLogInfo $appBase
        printLogInfo $docBase

        echo "============================================================================"
        echo;echo;
        
        done <<< "$psList"

exit;