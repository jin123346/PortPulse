
import logging
import xml.etree.ElementTree as ET


logger = logging.getLogger(__name__)


def parse_mof_items_xml(xml_text: str):
    logger.debug(
        "MOF API 응답 데이터: %s...",
        xml_text[:500]
    )

    root = ET.fromstring(xml_text)
    items = []

    for item in root.findall(".//item"):
        item_data = {}
        details = []

        for child in item:
            if child.tag == "details":
                for detail in child.findall("detail"):
                    detail_data = {}

                    for detail_child in detail:
                        detail_data[detail_child.tag] = detail_child.text

                    details.append(detail_data)

            else:
                item_data[child.tag] = child.text

        item_data["details"] = details
        items.append(item_data)

    total_count_text = root.findtext(".//totalCount")
    total_count = int(total_count_text) if total_count_text else 0

    logger.info(
        "totalCount: %s, type: %s",
        total_count,
        type(total_count)
    )

    return items, total_count