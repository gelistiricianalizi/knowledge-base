// Ölçüm için bilerek küçük tutulmuş örnek servis: yalnız standart kütüphane kullanır.
package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

const caBundlePath = "/etc/ssl/certs/ca-certificates.crt"

func main() {
	isCheck := flag.Bool("check", false, "çalışma ortamını denetle ve çık")
	flag.Parse()

	if *isCheck {
		os.Exit(checkRuntime())
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

// checkRuntime, statik bir binary'nin yine de imajdan beklediği iki dosyayı arar:
// saat dilimi veritabanı ve HTTPS için CA sertifika paketi. Dönüş değeri eksik sayısıdır.
func checkRuntime() int {
	missing := 0
	if _, err := time.LoadLocation("Europe/Istanbul"); err != nil {
		fmt.Println("timezone:        EKSİK -", err)
		missing++
	} else {
		fmt.Println("timezone:        var")
	}
	if _, err := os.Stat(caBundlePath); err != nil {
		fmt.Println("ca-certificates: EKSİK -", err)
		missing++
	} else {
		fmt.Println("ca-certificates: var")
	}
	return missing
}
