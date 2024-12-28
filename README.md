## xweb - A nginx + mysql + php environment

### commands:

`xweb.ps1 action_name targets`

- *`action_name`*: `fetch`, `init`, `install`, `start`, `stop`, `restart`
- *`targets`*: optional, possible values: `all`, `nginx`, `php`, `phpmyadmin`, `mysql`

examples:  

- `xweb.ps1 install`
- `xweb.ps1 fetch`
- `xweb.ps1 init`
- `xweb.ps1 start`
- `xweb.ps1 stop`
- `xweb.ps1 restart`

Note: if xweb was moved to other location, please rerun `xweb.ps1 init nginx -f`

## �������ݿ�ʧ�ܽ������

1. �������°汾 DMS ���������ݿ⣬û�� create table ��䣬����һ������?  

   �������: ����ʱѡ�񵼳������ݺͽṹ���� ��ѡѹ�� insert ���


2. ��ҳ����  

   ɾ����β: `FOREIGN_KEY_CHECKS` ������
   ȥ�� UTF-8 BOM

## ���� mysql ����:

- Linux
    vim /etc/my.cnf
    ```conf
    [mysql]
    skip-grant-table
    ```

    ```sh
    systemctl stop mysqld.service
    systemctl start mysqld.service
    mysql �Cu root
    ```

- Windows

1. ִ�У�`mysqld --skip-grant-tables`�����ڻ�һֱֹͣ����
2. Ȼ�������һ���������д��ڣ�ִ�� mysql������ֱ�ӽ���Mysql Command Line Cilent������ʱ�����������뼴�ɽ��롣
