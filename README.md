# BerkeleyRSF_CrowdMeter
This project tries to automatically track the crowd meter of RSF and provide an analysis

# Environment

Python 3.10

## Packages

see `requirements.txt`

# Scheduling

- cronjob

```shell
*/5 * * * * . /home/boyie/repo/side_projects/BerkeleyRSF_CrowdMeter/pyenv/bin/activate && python /home/boyie/repo/side_projects/BerkeleyRSF_CrowdMeter/main_crawl.py >> /home/boyie/repo/side_projects/BerkeleyRSF_CrowdMeter/logs/main_crawl.log 2>&1
*/5 * * * * cd /home/boyie/repo/side_projects/BerkeleyRSF_CrowdMeter && /usr/bin/Rscript /home/boyie/repo/side_projects/BerkeleyRSF_CrowdMeter/main_model.R >> /home/boyie/repo/side_projects/BerkeleyRSF_CrowdMeter/logs/main_model.log 2>&1
```
