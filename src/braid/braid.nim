#include <QDebug>
#include <QSqlQuery>
#include <QSqlError>
#include <QUuid>
#include <QtCore>

const QString HELIX_MARKER = "~";
const QString HELIX_ID = QString("%1node").arg(HELIX_MARKER);
const QString HELIX_ROOT_ID = QString("%1root_name").arg(HELIX_MARKER);
const QString HELIX_PARENT = QString("%1parent").arg(HELIX_MARKER);
const QString HELIX_NODE_NAME = QString("%1node_name").arg(HELIX_MARKER);
const QString HELIX_ITEM_ORDER = QString("%1item_order").arg(HELIX_MARKER);



Helix::Helix()
{
    DB = QSqlDatabase::addDatabase("QSQLITE", "RAM");
    DB.setDatabaseName(":memory:");  //set to empty string, if memory is being exhausted
    if (DB.open()) {
        initTable();
    }  else {
        qDebug() << "ERROR: RAM db failed to open - " << DB.lastError();
    }

    ProjectModel = new QSqlQueryModel;
}

Helix::~Helix()
{
    queryCommand("DELETE FROM helix");
    queryCommand("DROP TABLE helix");
    DB.close();
    delete ProjectModel;
}

void Helix::setModelQuery(QString qry)
{
    ProjectModel->setQuery(qry, DB);
}

bool Helix::queryCommand(QString qry_str, QString err_str)
{
    QSqlQuery qry(DB);
    if (!qry.exec(qry_str)) {
        qDebug() << "ERROR: " << err_str << " : \n"
                 << qry_str << " : \n" << qry.lastError();
        return false;
    }
    return true;
}

QSqlQuery Helix::queryResults(QString qry_str, QString err_str)
{
    QSqlQuery qry(DB);
    if (!qry.exec(qry_str)) {
        qDebug() << "ERROR: " << err_str << " : \n"
                 << qry_str << " : \n" << qry.lastError();
    }
    return qry;
}

void Helix::saveToDisk(QString filename)
{
    QSqlDatabase DiskDB = QSqlDatabase::addDatabase("QSQLITE","DISK");
    DiskDB.setDatabaseName(filename);
    if (DiskDB.open()) {
        QString attachstr = QString("ATTACH DATABASE '%1' AS %2")
                .arg(filename)
                .arg(DiskDB.connectionName());
        queryCommand(attachstr, "Attach Disk DB");

        QStringList tablesviews = DB.tables(QSql::Tables);
        foreach (QString tableorview, tablesviews) {
            if (!tableorview.contains("sqlite_sequence")) {
                QString insertstr =
                        QString("CREATE TABLE %2.%1 AS SELECT * FROM '%1'")
                        .arg(tableorview)
                        .arg(DiskDB.connectionName());
                queryCommand(insertstr);
            }
        }
        QString detachstr = QString("DETACH %1")
                .arg(DiskDB.connectionName());
        queryCommand(detachstr);
        DiskDB.close();
    }  else {
        QString error_string =
                QString("ERROR: database :memory: at MEM failed to open - ")
                .arg(DiskDB.lastError().text());
        qDebug() << error_string;
    }

}

Helix::Node Helix::getNode(QString node_id, QString table)
{
    Helix::Node return_node(node_id, DB, table);
    QString node_str = QString("SELECT * FROM \'%1\' WHERE node = \'%2\'")
            .arg(table)
            .arg(node_id);
    QSqlQuery node_data(queryResults(node_str));
    while (node_data.next()) {
//        if (HELIX_ID == node_data.value("property").toString()) {
//            return_node->setHelixId(node_id);
//        } else
            if (HELIX_PARENT == node_data.value("property").toString()) {
            return_node.setHelixParent(node_data.value("datum").toString());
        } else if (HELIX_NODE_NAME == node_data.value("property").toString()) {
            return_node.setHelixNodeName(node_data.value("datum").toString());
        } else if (HELIX_ITEM_ORDER == node_data.value("property").toString()) {
            return_node.setHelixItemOrder(node_data.value("datum").toInt());
        }
    }
}

Helix::Node *Helix::createNode(QString node_id, QString table)
{
    return new Node(node_id, DB, table);
}

QList<Helix::Node> Helix::getRootNodes(QString table)
{
    QList<Helix::Node> return_nodes;
    QString node_str = QString("SELECT * FROM \'%1\' WHERE property = \'%2\'")
            .arg(table)
            .arg(HELIX_ROOT_ID);
    QSqlQuery node_data(queryResults(node_str));
    while (node_data.next()) {
        QString node_id = node_data.value("node").toString();
        return_nodes.append(getNode(node_id));
    }
    return return_nodes;
}

QList<Helix::Node> Helix::getAllNodes(QString table)
{
    QList<Helix::Node> return_nodes;
    QString node_str = QString("SELECT * FROM \'%1\' WHERE property = \'%2\'")
            .arg(table)
            .arg(HELIX_ID);
    QSqlQuery node_data(queryResults(node_str));
    while (node_data.next()) {
        QString node_id = node_data.value("node").toString();
        return_nodes.append(getNode(node_id));
    }
    return return_nodes;
}

void Helix::deleteNode()
{

}

QString Helix::getNewUUID()
{
    return QUuid::createUuid().toString().remove("{").remove("}");
}

bool Helix::initTable()
{
    bool ok;
    QSqlQuery helix(DB);
    ok = helix.exec("CREATE TABLE helix ("
                    "edge INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,"
                    "node TEXT,"
                    "property TEXT,"
                    "datum TEXT,"
                    "stamp TIMESTAMP,"
                    "inclusion REAL);");
    //                  CREATE INDEX IF NOT EXISTS idx_t_edge_node ON t_edge (node);
    if (!ok)
        qDebug() << "ERROR: initTable() - " << helix.lastError();
    return ok;
}

//void Helix::beginTransaction()
//{
//    queryCommand("BEGIN");
//}

//void Helix::endTransaction()
//{
//    queryCommand("COMMIT");
//}

void Helix::importJSON(QString json_string, QString root_id)
{
    cJSON *insert_data = cJSON_Parse(json_string.toLocal8Bit());
    if (insert_data){
        QString new_node = getNewUUID();
        insertRecord(HELIX_ID, 1, new_node, new_node);
        insertRecord(HELIX_ROOT_ID, 1, root_id, new_node);

        parse_object(insert_data, new_node);

        foreach (QString view_name, getViewOptions()) {
             QString new_view =
                    QString("CREATE VIEW '%1_view' AS SELECT * FROM helix WHERE property = '%1'")
                    .arg(view_name);
            queryCommand(new_view);
        }
    } else {
        qDebug() << cJSON_GetErrorPtr();
    }
}


void Helix::parse_object(cJSON *item, QString parent_node)
{
    quint32 item_order = 0;
    cJSON *subitem=item->child;
    while (subitem)
    {   // handle subitem
        QString new_node = getNewUUID();
        insertRecord(HELIX_ID, 1, new_node, new_node);
        insertRecord(HELIX_ITEM_ORDER, 1, QString::number(item_order++), new_node);
        insertRecord(HELIX_PARENT, 1, parent_node, new_node);
        QString property = "";
        QVariant value;
        switch (subitem->type) {
        case 6: //object
            parse_object(subitem, new_node);
            property = HELIX_NODE_NAME;
            value = subitem->string;
            break;
        case 5: //array
            property = HELIX_NODE_NAME;
            value = subitem->string;
            parse_object(subitem, new_node);
            break;
        case 4: //string
            value = subitem->valuestring;
            break;
        case 3: //number
            value = (subitem->valueint)
                    ? subitem->valueint
                    : subitem->valuedouble;
            break;
        case 2: //NULL;
            value = "";
            break;
        case 1: //true
            value = true;
            break;
        case 0: //false
            value = false;
            break;
            //        case 256:
            //            //do reference
            //            break;
        default:
            value = subitem->valuestring;
            break;
        }
        if (property == "")
            property = subitem->string;

        insertRecord(property, 1, value.toString(), new_node);
        if (subitem->child) parse_object(subitem->child, new_node);

        subitem=subitem->next;
    }
}

//void Helix::fullSpeedTest()
//{
//    queryCommand("SELECT * FROM helix WHERE node = 'will not be found';");
//}

QSqlQueryModel *Helix::getProjectModel()
{
    return ProjectModel;
}

bool Helix::insertRecord(QString property, qreal inclusion, QString datum, QString node)
{
    bool ok;
    if (node == "AutoGen")
        node = getNewUUID();

    QSqlQuery helix(DB);
    helix.prepare("INSERT INTO helix (node, property, datum, stamp, inclusion)"
                  "VALUES (:node, :property, :datum, :stamp, :inclusion);");
    helix.bindValue(":node", node);
    helix.bindValue(":property", property);
    helix.bindValue(":datum", datum);
    helix.bindValue(":stamp", QDateTime::currentMSecsSinceEpoch());
    helix.bindValue(":inclusion", inclusion);
    ok = helix.exec();

    if (!ok)
        qDebug() << "ERROR: insertRecord() - " << helix.lastError();
    return ok;
}

QStringList Helix::getViewOptions()
{
    QStringList view_options;
    QSqlQuery properties(queryResults("SELECT DISTINCT property FROM helix"));
    while (properties.next()) {
        QString view_name = properties.value("property").toString();
//        if (!view_name.startsWith("~")) {
            view_options.append(view_name);
//        }
    }
    return view_options;
}



Helix::Node::~Node()
{

}

Helix::Node Helix::Node::getHelixRootId()
{

}

QMap<QString, QString> Helix::Node::getData()
{

}

QList<Helix::Node> Helix::Node::getChildren()
{

}

Helix::Node::Node(QString node_id, QSqlDatabase db, QString table) :
    Helix_Id(node_id),
    Helix_Item_Order(0),
    Helix_Node_Name(""),
    Helix_Parent("0")
{

}


