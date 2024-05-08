# Load Balancing Exercise

The repository contains an example P4 program for educational purposes. A single switch performs load balancing of a UDP-based client-server communication.

## Problem Description

We have a simplified network of 4 hosts (h1, h2, h3, h4) connected via a single P4-programmable switch (s1). 

h1 represents the client by running the `load-balancer.p4app/client.py` script. It sends ASCII strings using UDP. After each query, it expects to get the reversed string as a response.

h2, h3, h4 are servers runnig the `load-balancer.p4app/server.py` script. They listen on port 5555.

Our task is to program s1 so that it performs load balancing among the servers. The solution should treat queries starting with the character `a` special. Queries starting with `a` can be processed only by h2. Moreover, only these special requests should be assigned to h2. (At the end of this document, there are additional exercises that you can perform on your own.)

## Environment Setup and Usage

1. It is recommended to run this exercise in a small VM. One option is [multipass](https://multipass.run/install) which is available for Linux, Windows and Mac. After installing it, you can quickly create a small VM and connect to it using the following commands:

    ```
    multipass launch -n p4-lecture-vm
    multipass shell p4-lecture-vm
    ```

2. Make sure you have [p4app](https://github.com/p4lang/p4app) installed. One way of installing them in your multipass Ubuntu VM is as follows.

    ```
    sudo apt update
    sudo apt install docker-compose
    git clone https://github.com/p4lang/p4app.git
    sudo cp p4app/p4app /usr/local/bin
    ```

3. Clone this repository.

4. You can start the P4 program using the following command:

    ```
    sudo p4app run load-balancer.p4app
    ```

    The first start might take longer since `p4app` will pull some docker images.

    This command builds the P4 code and runs it inside a mininet network. You should see a `mininet` console at the end.



5. The `config.sh ` script sets the IP addresses of the different hosts in the mininet network.

    ```
    sudo bash config.sh
    ```

6. The `experiment.sh` script runs the `client.py` and `server.py` scripts on the appropriate hosts.

    ```
    sudo bash experiment.sh
    ```

    Make sure that you are running this command in a different terminal, not in the `mininet` console.

7. You can stop your testbed by issuing the `quit` command in the `mininet` console.

## Implementing a Simple Load Balancing

The repository already contains the solution for the load balancer. The main points in the main.p4 file are as follows.

- At the beginning, we define every header we want to use. Notice the `char1` header that contains a single character. We can use this later to distinguish special queries starting with the character `a`.
- `MyParser` parses the previously defined headers.
- `MyIngress` contains our main logic.
    - For technical reasons, it implements some ARP features. Thanks to the `respond_to_arp` table, the switch can respond to ARP requests with the hardcoded values.
    - The `mac_forwarding` table implements an L2 forwarding based on static values.
    - If we are processing a non-special UDP packet belonging to the string reversing service, we generate a random number using the `random` extern and override the destination addresses of the Ethernet and IPv4 headers. (Don't forget about the IP and UDP checksums! :) )
    - If we see a response, we override the source addresses. (And fix the UDP checksum.)
- `MyComputeChecksum` recalculates the IPv4 checksum using the appropriate extern function.
- Finally, `MyDeparser` reassembles the packet.

## Additional exercises

1. You may notice that reversing one-character-long ASCII strings does not require any calculation. Modify the P4 code so that the switch automatically responds to these queries.
    - You can use the `standard_metadata.ingress_port` and `standard_metadata.egress_spec` fields to get the original incoming port and set the outgoing one.
    - Do not forget about the checksums.


2. Processing 2 or 3 long strings is also simple. It can be done by swapping two characters. 
    - Make sure you don't want to parse more characters than the total length of your query. (Hint: the hdr.udp.len filed can be useful.)

3. **(BONUS EXERCISE)** Modify the P4 code so that it can answer every query up to 8 characters without swapping characters.