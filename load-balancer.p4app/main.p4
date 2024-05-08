#include <core.p4>
#include <v1model.p4>

/***** Header definitions *****/

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header arp_t {
    bit<16> hardware_type;
    bit<16> protocol_type;
    bit<8> hardware_length;
    bit<8> protocol_length;
    bit<16> operation;

    bit<48> sender_hw_addr;
    bit<32> sender_ip_addr;
    bit<48> target_hw_addr;
    bit<32> target_ip_addr;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> src;
    bit<32> dst;
}

header udp_t{
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> len;
    bit<16> csum;
}

header char1_t{
    bit<8> c;
}

/***** Struct representing the possible headers *****/

struct headers {
    ethernet_t   ethernet;
    arp_t        arp;
    ipv4_t       ipv4;
    udp_t        udp;
    char1_t      char1;
}

/***** User defined metadata structure *****/

struct metadata {
}

/***** Parser *****/

parser MyParser(packet_in pkt,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            16w0x0800: parse_ipv4;
            16w0x0806: parse_arp;
            default: accept;
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            17  : parse_udp;
            default: accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dstPort){
            5555  : parse_char1;
            default: accept;
        }
    }

    state parse_char1 {
        pkt.extract(hdr.char1);
        transition accept;
    }

}


/***** (Unused) control block for checksum verification *****/

control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}


/***** Ingress pipeline *****/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {


    /*** action to drop a packet ***/
    
    action drop_packet(){
        mark_to_drop(standard_metadata);
    }


    /*** table + action for ARP responses ***/
    
    action respond_to_arp(bit<48> mac_addr){
        // fill in the ARP header on behalf of the target
        hdr.arp.operation = 2;  

        bit<32> tmp_ip = hdr.arp.target_ip_addr;
        hdr.arp.target_ip_addr = hdr.arp.sender_ip_addr;
        hdr.arp.sender_ip_addr = tmp_ip;
        
        hdr.arp.target_hw_addr = hdr.ethernet.srcAddr;
        hdr.arp.sender_hw_addr = mac_addr;
        hdr.arp.target_hw_addr = hdr.arp.sender_hw_addr;

        // send back the packet
        hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = mac_addr;
        standard_metadata.egress_spec = standard_metadata.ingress_port;
    }
    
    table arp_respond{
        key = {
            hdr.arp.target_ip_addr: exact;
        }
        actions = {
            respond_to_arp;
            drop_packet;
        }
        const default_action = drop_packet;
        const entries = {
                0x0a000a01 : respond_to_arp(0x000400000000);
                0x0a000a02 : respond_to_arp(0x000400000001);
                0x0a000a03 : respond_to_arp(0x000400000002);
                0x0a000a04 : respond_to_arp(0x000400000003);
                0x0a000a05 : respond_to_arp(0x000400000004);
        }
    }


    /*** table + action for MAC forwarding ***/

    action set_eport(bit<9> port){
        standard_metadata.egress_spec = port;
    }

    table mac_forwarding{
        key = {
            hdr.ethernet.dstAddr: exact;
        }
        actions = {
            set_eport;
            drop_packet;
        }
        const default_action = drop_packet;
        const entries = {
                0x000400000000 : set_eport(1);
                0x000400000001 : set_eport(2);
                0x000400000002 : set_eport(3);
                0x000400000003 : set_eport(4);
        }
    }

    apply {        
        // *** static forwarding based on destination MAC address
        if (hdr.arp.isValid()){
            arp_respond.apply();
        }
        else{
            if (hdr.udp.isValid() && hdr.udp.dstPort == 5555 && hdr.char1.c != 97){
                // this is a packet we need to load balance
                bit<8> random_number;
                random(random_number,0,1);
                if (random_number==0){
                    // send to h3
                    hdr.ipv4.dst = 0x0a000a03;
                    hdr.ethernet.dstAddr = 0x000400000002;
                    hdr.udp.csum = 0;
                }
                else if (random_number==1){
                    // send to h4
                    hdr.ipv4.dst = 0x0a000a04;
                    hdr.ethernet.dstAddr = 0x000400000003;
                    hdr.udp.csum = 0;
                }
            }
            else if (hdr.udp.isValid() && hdr.udp.srcPort == 5555){
                // this is a load balanced response
                // make it look like h2 sent the packet
                hdr.ipv4.src = 0x0a000a02;
                hdr.ethernet.srcAddr = 0x000400000001;
                hdr.udp.csum = 0;
            }

            mac_forwarding.apply();
        }
        

    }
}

/***** (Unused) egress block *****/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}


/***** Block for fixing checksums *****/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
                hdr.ipv4.isValid(),
                { 
                hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv,
                hdr.ipv4.totalLen, hdr.ipv4.identification,
                hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl,
                hdr.ipv4.protocol, hdr.ipv4.src, hdr.ipv4.dst 
                },
                hdr.ipv4.hdrChecksum,
                HashAlgorithm.csum16
            );
    }
}

/***** Deparser *****/

control MyDeparser(packet_out pkt, in headers hdr) {
    apply {
        pkt.emit(hdr);
    }
}

/***** Let's put together everything *****/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
